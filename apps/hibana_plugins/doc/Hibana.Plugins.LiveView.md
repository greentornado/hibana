# `Hibana.Plugins.LiveView`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/live_view_channel.ex#L1)

LiveView channel plugin for real-time WebSocket connections.

## Features

- WebSocket upgrade handling for LiveView
- Phoenix-style LiveView socket management
- Event handling from client
- Server-rendered HTML updates

## Usage

    plug Hibana.Plugins.LiveView, handler: MyApp.CounterLive

## Routes

Access LiveView at:

    GET /lv/socket/*path

## LiveView Handler

Create a handler module:

    defmodule MyApp.CounterLive do
      use Hibana.LiveView

      def mount(_params, _session, socket) do
        {:ok, assign(socket, count: 0)}
      end

      def render(assigns) do
        "<div>Count: #{assigns[:count]}</div>"
      end

      def handle_event("increment", _params, socket) do
        {:noreply, assign(socket, count: socket.assigns.count + 1)}
      end
    end

## WebSocket Connection

Client connects to:

    ws://localhost:4000/lv/socket/counter

Send events as JSON:

    ws.send(JSON.stringify({event: "increment", value: 1}))

## Module Functions

### build_socket/3
Build a LiveView socket:

    socket = Hibana.Plugins.LiveView.build_socket(handler, endpoint, id)

### handle_event/4
Handle incoming events:

    new_socket = LiveView.handle_event(socket, "click", %{}, handler)

### render/2
Render the LiveView template:

    html = LiveView.render(socket, handler)

## Options

- `:handler` - The LiveView handler module that implements `mount/3`, `render/1`, and `handle_event/3` callbacks (required)

# `before_send`

# `build_socket`

# `handle_event`

# `render`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
