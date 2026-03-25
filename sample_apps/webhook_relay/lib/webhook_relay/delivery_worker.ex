defmodule WebhookRelay.DeliveryWorker do
  @moduledoc """
  GenServer that processes webhook delivery jobs.
  Delivers via HTTP POST with HMAC signing and retries with exponential backoff.
  Each subscription URL gets a circuit breaker (5 failures -> open for 30s).
  """

  use GenServer

  require Logger

  @max_retries 3
  @base_backoff_ms 1_000
  @circuit_threshold 5
  @circuit_timeout_ms 30_000

  # --- Public API ---

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Enqueue a delivery job."
  def enqueue(event_id, subscription) do
    GenServer.cast(__MODULE__, {:deliver, event_id, subscription, 0})
  end

  # --- GenServer callbacks ---

  def init(_) do
    # Circuit breaker state: %{url => %{failures: n, opened_at: DateTime | nil}}
    {:ok, %{circuits: %{}}}
  end

  def handle_cast({:deliver, event_id, subscription, attempt}, state) do
    url = subscription.url

    case check_circuit(state.circuits, url) do
      :open ->
        Logger.warning("[DeliveryWorker] Circuit open for #{url}, skipping delivery")

        WebhookRelay.EventStore.update_delivery(
          event_id,
          subscription.id,
          "circuit_open",
          attempt
        )

        {:noreply, state}

      :closed ->
        state = do_deliver(event_id, subscription, attempt, state)
        {:noreply, state}
    end
  end

  # --- Private ---

  defp do_deliver(event_id, subscription, attempt, state) do
    case WebhookRelay.EventStore.get_event(event_id) do
      {:ok, event} ->
        body = Jason.encode!(event.payload)
        signature_headers = WebhookRelay.Signer.sign(body, subscription.secret)

        headers = [
          {"Content-Type", "application/json"},
          {"X-Webhook-Id", event_id},
          {"X-Webhook-Channel", event.channel},
          {"X-Timestamp", signature_headers["X-Timestamp"]},
          {"X-Signature", signature_headers["X-Signature"]}
        ]

        case http_post(subscription.url, headers, body) do
          {:ok, status} when status >= 200 and status < 300 ->
            Logger.info(
              "[DeliveryWorker] Delivered #{event_id} to #{subscription.url} (#{status})"
            )

            WebhookRelay.EventStore.update_delivery(
              event_id,
              subscription.id,
              "delivered",
              attempt + 1
            )

            reset_circuit(state, subscription.url)

          {:ok, status} ->
            Logger.warning(
              "[DeliveryWorker] Failed #{event_id} to #{subscription.url} (#{status})"
            )

            handle_failure(event_id, subscription, attempt, state)

          {:error, reason} ->
            Logger.warning(
              "[DeliveryWorker] Error #{event_id} to #{subscription.url}: #{inspect(reason)}"
            )

            handle_failure(event_id, subscription, attempt, state)
        end

      {:error, :not_found} ->
        Logger.warning("[DeliveryWorker] Event #{event_id} not found, skipping")
        state
    end
  end

  defp handle_failure(event_id, subscription, attempt, state) do
    state = record_failure(state, subscription.url)

    if attempt < @max_retries do
      backoff = @base_backoff_ms * :math.pow(2, attempt) |> round()

      WebhookRelay.EventStore.update_delivery(
        event_id,
        subscription.id,
        "retrying",
        attempt + 1
      )

      Process.send_after(self(), {:retry, event_id, subscription, attempt + 1}, backoff)
      state
    else
      WebhookRelay.EventStore.update_delivery(
        event_id,
        subscription.id,
        "failed",
        attempt + 1
      )

      state
    end
  end

  def handle_info({:retry, event_id, subscription, attempt}, state) do
    state = do_deliver(event_id, subscription, attempt, state)
    {:noreply, state}
  end

  defp http_post(url, headers, body) do
    # Use hackney if available, otherwise fall back to httpc
    case Code.ensure_loaded(:hackney) do
      {:module, :hackney} ->
        case :hackney.request(:post, url, headers, body, [:with_body, recv_timeout: 10_000]) do
          {:ok, status, _headers, _body} -> {:ok, status}
          {:error, reason} -> {:error, reason}
        end

      _ ->
        # Fallback to httpc (Erlang built-in)
        uri = String.to_charlist(url)

        http_headers =
          Enum.map(headers, fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

        request = {uri, http_headers, ~c"application/json", body}

        case :httpc.request(:post, request, [timeout: 10_000], []) do
          {:ok, {{_, status, _}, _, _}} -> {:ok, status}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # --- Circuit breaker logic ---

  defp check_circuit(circuits, url) do
    case Map.get(circuits, url) do
      %{failures: f, opened_at: opened_at} when f >= @circuit_threshold and opened_at != nil ->
        elapsed = System.monotonic_time(:millisecond) - opened_at

        if elapsed < @circuit_timeout_ms do
          :open
        else
          :closed
        end

      _ ->
        :closed
    end
  end

  defp record_failure(state, url) do
    circuit = Map.get(state.circuits, url, %{failures: 0, opened_at: nil})
    failures = circuit.failures + 1

    opened_at =
      if failures >= @circuit_threshold do
        circuit.opened_at || System.monotonic_time(:millisecond)
      else
        nil
      end

    circuits = Map.put(state.circuits, url, %{failures: failures, opened_at: opened_at})
    %{state | circuits: circuits}
  end

  defp reset_circuit(state, url) do
    circuits = Map.delete(state.circuits, url)
    %{state | circuits: circuits}
  end
end
