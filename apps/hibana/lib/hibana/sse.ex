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
  Initializes an SSE connection with proper headers and chunked encoding.

  Sets `Content-Type: text/event-stream`, disables caching, and starts
  chunked transfer encoding. Sends an initial `retry:` directive to the client.

  ## Parameters

    - `conn` - The `Plug.Conn` struct
    - `opts` - Options:
      - `:retry` - Client reconnection interval in milliseconds (default: `3000`)

  ## Returns

  The connection in chunked mode, ready for `send_event/4` calls.

  ## Examples

      ```elixir
      conn = Hibana.SSE.init(conn)
      conn = Hibana.SSE.init(conn, retry: 5000)
      ```
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
  Sends an SSE event with a named event type and optional ID.

  Formats the event according to the W3C SSE specification and sends
  it as a chunk on the connection.

  ## Parameters

    - `conn` - The chunked connection (from `init/1`)
    - `event_type` - The event name (e.g., `"message"`, `"update"`)
    - `data` - The event payload (string or JSON-encodable term)
    - `opts` - Options:
      - `:id` - Optional event ID for client-side tracking

  ## Returns

    - `{:ok, conn}` on success
    - `{:error, reason}` if the connection is closed

  ## Examples

      ```elixir
      {:ok, conn} = Hibana.SSE.send_event(conn, "message", %{text: "Hello!"})
      {:ok, conn} = Hibana.SSE.send_event(conn, "update", %{count: 42}, id: 1)
      ```
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
  Sends a data-only SSE event without an event type.

  The client will receive this as a generic `message` event.

  ## Parameters

    - `conn` - The chunked connection (from `init/1`)
    - `data` - The event payload (string or JSON-encodable term)

  ## Returns

    - `{:ok, conn}` on success
    - `{:error, reason}` if the connection is closed

  ## Examples

      ```elixir
      {:ok, conn} = Hibana.SSE.send_data(conn, %{status: "online"})
      {:ok, conn} = Hibana.SSE.send_data(conn, "heartbeat")
      ```
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
  Sends an SSE comment line, typically used as a keep-alive signal.

  Comments are prefixed with `:` and ignored by SSE clients but keep
  the HTTP connection alive through proxies and load balancers.

  ## Parameters

    - `conn` - The chunked connection
    - `comment` - Optional comment text (default: `""`)

  ## Returns

    - `{:ok, conn}` on success
    - `{:error, :closed}` if the connection is closed

  ## Examples

      ```elixir
      {:ok, conn} = Hibana.SSE.send_comment(conn)
      {:ok, conn} = Hibana.SSE.send_comment(conn, "keepalive")
      ```
  """
  def send_comment(conn, comment \\ "") do
    case chunk(conn, ": #{comment}\n\n") do
      {:ok, conn} -> {:ok, conn}
      {:error, _} -> {:error, :closed}
    end
  end

  @doc """
  Streams events using a callback function.

  The callback receives a `send_fn` that can be called repeatedly to emit
  SSE events. The function should block until streaming is complete.

  ## Parameters

    - `conn` - The chunked connection (from `init/1`)
    - `fun` - A function that receives `send_fn.(event_type, data)` and streams events
    - `_opts` - Reserved for future use

  ## Returns

  The connection after streaming.

  ## Examples

      ```elixir
      Hibana.SSE.stream(conn, fn send_fn ->
        send_fn.("message", %{text: "Hello!"})
        Process.sleep(1000)
        send_fn.("message", %{text: "World!"})
      end)
      ```
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

  ## Blocking Behavior Warning

  This function blocks the calling process indefinitely (or until timeout).
  It should be used inside a spawned process or Task to avoid blocking
  the request handler. The connection process will be tied to this loop.

  ## Example

      # Spawn in a separate process to avoid blocking
      Task.start(fn ->
        Hibana.SSE.stream_loop(conn, keep_alive: 30_000)
      end)
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
