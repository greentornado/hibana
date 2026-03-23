defmodule Hibana.SSE do
  @moduledoc """
  Server-Sent Events (SSE) support for real-time streaming.

  ## Usage

      # In your controller
      def stream(conn) do
        conn = Hibana.SSE.init(conn)

        # Send events
        Hibana.SSE.send_event(conn, "message", %{text: "Hello!"})
        Hibana.SSE.send_event(conn, "update", %{count: 42})

        # Or stream from a GenServer/process
        Hibana.SSE.stream(conn, fn send_fn ->
          # send_fn sends an SSE event
          send_fn.("heartbeat", %{time: DateTime.utc_now()})
          Process.sleep(1000)
          send_fn.("heartbeat", %{time: DateTime.utc_now()})
        end)
      end

  ## With a topic (PubSub-style)

      def live_updates(conn) do
        Hibana.SSE.subscribe(conn, "updates", fn event ->
          # Transform events before sending
          %{type: "update", data: event}
        end)
      end

  ## Event Format

  SSE events follow the W3C specification:

      event: message
      data: {"text":"Hello!"}
      id: 1

  ## Options

  - `:keep_alive` - Send comment every N ms to keep connection alive (default: 15_000)
  - `:retry` - Client retry interval in ms (default: 3_000)
  """

  import Plug.Conn

  @doc """
  Initialize an SSE connection with proper headers.
  """
  def init(conn, opts \\ []) do
    retry = Keyword.get(opts, :retry, 3000)

    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache, no-store, must-revalidate")
    |> put_resp_header("connection", "keep-alive")
    |> put_resp_header("x-accel-buffering", "no")
    |> send_chunked(200)
    |> send_retry(retry)
  end

  @doc """
  Send an SSE event with optional event type and id.
  """
  def send_event(conn, event_type, data, opts \\ []) do
    id = Keyword.get(opts, :id)
    encoded_data = if is_binary(data), do: data, else: Jason.encode!(data)

    payload =
      [
        if(id, do: "id: #{id}\n", else: ""),
        "event: #{event_type}\n",
        format_data(encoded_data),
        "\n"
      ]
      |> IO.iodata_to_binary()

    case chunk(conn, payload) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a data-only event (no event type).
  """
  def send_data(conn, data) do
    encoded_data = if is_binary(data), do: data, else: Jason.encode!(data)

    payload = format_data(encoded_data) <> "\n"

    case chunk(conn, payload) do
      {:ok, conn} -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Send a comment (keep-alive).
  """
  def send_comment(conn, comment \\ "") do
    case chunk(conn, ": #{comment}\n\n") do
      {:ok, conn} -> {:ok, conn}
      {:error, _} -> {:error, :closed}
    end
  end

  @doc """
  Stream events using a callback function.
  The callback receives a send function that can be called to emit events.
  """
  def stream(conn, fun, _opts \\ []) do
    send_fn = fn event_type, data ->
      send_event(conn, event_type, data)
    end

    fun.(send_fn)

    conn
  end

  @doc """
  Stream events from a process mailbox. Listens for messages and sends them as SSE events.

  Expects messages in the format `{:sse_event, type, data}`.
  Stops when receiving `:sse_close` or when the connection is closed.
  """
  def stream_loop(conn, opts \\ []) do
    keep_alive = Keyword.get(opts, :keep_alive, 15_000)
    timeout = Keyword.get(opts, :timeout, :infinity)

    do_stream_loop(conn, keep_alive, timeout)
  end

  defp do_stream_loop(conn, keep_alive, timeout) do
    effective_timeout = min(keep_alive, timeout || keep_alive)

    receive do
      {:sse_event, event_type, data} ->
        case send_event(conn, event_type, data) do
          {:ok, conn} -> do_stream_loop(conn, keep_alive, timeout)
          {:error, _} -> conn
        end

      {:sse_event, event_type, data, opts} ->
        case send_event(conn, event_type, data, opts) do
          {:ok, conn} -> do_stream_loop(conn, keep_alive, timeout)
          {:error, _} -> conn
        end

      :sse_close ->
        conn
    after
      effective_timeout ->
        case send_comment(conn) do
          {:ok, conn} -> do_stream_loop(conn, keep_alive, timeout)
          {:error, _} -> conn
        end
    end
  end

  defp send_retry(conn, retry) do
    case chunk(conn, "retry: #{retry}\n\n") do
      {:ok, conn} -> conn
      _ -> conn
    end
  end

  defp format_data(data) do
    data
    |> String.split("\n")
    |> Enum.map_join("\n", &"data: #{&1}")
    |> Kernel.<>("\n")
  end
end
