# `Hibana.LiveView`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/live_view.ex#L1)

LiveView behavior for real-time server-rendered HTML.

## Usage

    # Define a LiveView
    defmodule MyApp.CounterLive do
      use Hibana.LiveView

      def mount(_params, _session, socket) do
        {:ok, assign(socket, count: 0)}
      end

      # Return HTML string
      def render(assigns) do
        "<div><h1>Count: #{assigns[:count]}</h1></div>"
      end

      def handle_event("increment", _params, socket) do
        {:noreply, assign(socket, count: socket.assigns.count + 1)}
      end
    end

# `handle_connect`

```elixir
@callback handle_connect(socket :: Hibana.LiveView.Socket.t()) ::
  {:ok, Hibana.LiveView.Socket.t()}
```

Handle websocket connection

# `handle_event`

```elixir
@callback handle_event(
  event :: String.t(),
  params :: map(),
  socket :: Hibana.LiveView.Socket.t()
) ::
  {:noreply, Hibana.LiveView.Socket.t()}
  | {:reply, map(), Hibana.LiveView.Socket.t()}
  | {:stop, Hibana.LiveView.Socket.t()}
```

Handle incoming events from client (phx-click, phx-submit, etc.)

# `handle_info`

```elixir
@callback handle_info(msg :: any(), socket :: Hibana.LiveView.Socket.t()) ::
  {:noreply, Hibana.LiveView.Socket.t()} | {:stop, Hibana.LiveView.Socket.t()}
```

Handle incoming info messages (from GenServer, etc.)

# `mount`

```elixir
@callback mount(params :: map(), session :: map(), socket :: Hibana.LiveView.Socket.t()) ::
  {:ok, Hibana.LiveView.Socket.t()}
  | {:ok, Hibana.LiveView.Socket.t(), keyword()}
  | {:error, any()}
```

Called when LiveView is mounted. Return {:ok, socket} or {:error, reason}.

# `render`

```elixir
@callback render(assigns :: map()) :: String.t()
```

Renders the LiveView template. Must return HTML string.

# `terminate`

```elixir
@callback terminate(reason :: any(), socket :: Hibana.LiveView.Socket.t()) :: :ok
```

Called when LiveView is being terminated

# `connected`

Marks socket as connected (after WebSocket handshake).

# `push`

Pushes an event to the client.

# `redirect`

Redirects to a different URL.

# `render_template`

Renders a template with assigns.

# `socket`

Creates a new LiveView socket.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
