# `Hibana.SSE`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/sse.ex#L1)

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

# `init`

Initialize an SSE connection with proper headers.

# `send_comment`

Send a comment (keep-alive).

# `send_data`

Send a data-only event (no event type).

# `send_event`

Send an SSE event with optional event type and id.

# `stream`

Stream events using a callback function.
The callback receives a send function that can be called to emit events.

# `stream_loop`

Stream events from a process mailbox. Listens for messages and sends them as SSE events.

Expects messages in the format `{:sse_event, type, data}`.
Stops when receiving `:sse_close` or when the connection is closed.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
