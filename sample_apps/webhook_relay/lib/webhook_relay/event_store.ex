defmodule WebhookRelay.EventStore do
  @moduledoc """
  ETS-based event log. Stores webhook events with delivery status.
  Each event: %{id, channel, payload, received_at, deliveries: [...]}
  """

  use GenServer

  @table :webhook_events

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :ordered_set, :public, read_concurrency: true])
    {:ok, %{counter: 0}}
  end

  @doc "Store a new event and return its id."
  def store_event(channel, payload) do
    id = generate_id()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    event = %{
      id: id,
      channel: channel,
      payload: payload,
      received_at: now,
      deliveries: []
    }

    :ets.insert(@table, {id, event})
    {:ok, event}
  end

  @doc "Get an event by id."
  def get_event(id) do
    case :ets.lookup(@table, id) do
      [{^id, event}] -> {:ok, event}
      [] -> {:error, :not_found}
    end
  end

  @doc "List recent events (most recent first), limited to `limit`."
  def list_events(limit \\ 50) do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, event} -> event end)
    |> Enum.sort_by(& &1.received_at, :desc)
    |> Enum.take(limit)
  end

  @doc "List events for a specific channel."
  def list_events_for_channel(channel, limit \\ 50) do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, event} -> event end)
    |> Enum.filter(fn e -> e.channel == channel end)
    |> Enum.sort_by(& &1.received_at, :desc)
    |> Enum.take(limit)
  end

  @doc "Update delivery status for an event."
  def update_delivery(event_id, subscription_id, status, attempts) do
    case get_event(event_id) do
      {:ok, event} ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()

        delivery = %{
          subscription_id: subscription_id,
          status: status,
          attempts: attempts,
          last_attempt: now
        }

        # Replace existing delivery for this subscription or add new one
        deliveries =
          event.deliveries
          |> Enum.reject(fn d -> d.subscription_id == subscription_id end)
          |> then(fn ds -> [delivery | ds] end)

        updated = %{event | deliveries: deliveries}
        :ets.insert(@table, {event_id, updated})
        {:ok, updated}

      error ->
        error
    end
  end

  @doc "Count events for a channel."
  def event_count(channel) do
    :ets.tab2list(@table)
    |> Enum.count(fn {_id, event} -> event.channel == channel end)
  end

  @doc "Get the most recent event for a channel."
  def last_event(channel) do
    list_events_for_channel(channel, 1) |> List.first()
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)
  end
end
