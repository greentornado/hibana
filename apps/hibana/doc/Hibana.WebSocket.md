# `Hibana.WebSocket`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/web_socket.ex#L1)

WebSocket handler behavior for Hibana.

## Usage

    defmodule MyApp.ChatSocket do
      use Hibana.WebSocket

      def handle_in(msg, state) do
        {:reply, {:text, "echo: #{msg}"}, state}
      end
    end

## Routing

In your router, call `Hibana.WebSocket.upgrade/3`:

    get "/ws/chat", fn conn ->
      Hibana.WebSocket.upgrade(conn, MyApp.ChatSocket)
    end

Or in a controller:

    def websocket(conn) do
      Hibana.WebSocket.upgrade(conn, MyApp.ChatSocket)
    end

# `handle_binary`

```elixir
@callback handle_binary(message :: binary(), state :: map()) ::
  {:ok, map()} | {:reply, reply :: any(), map()} | {:stop, map()}
```

# `handle_connect`

```elixir
@callback handle_connect(info :: any(), state :: map()) :: {:ok, map()} | {:stop, map()}
```

# `handle_disconnect`

```elixir
@callback handle_disconnect(reason :: any(), state :: map()) :: {:ok, map()}
```

# `handle_in`

```elixir
@callback handle_in(message :: String.t(), state :: map()) ::
  {:ok, map()} | {:reply, reply :: any(), map()} | {:stop, map()}
```

# `handle_info`

```elixir
@callback handle_info(message :: any(), state :: map()) ::
  {:ok, map()} | {:push, push :: any(), map()} | {:stop, map()}
```

# `init`

```elixir
@callback init(conn :: Plug.Conn.t(), opts :: any()) ::
  {:ok, Plug.Conn.t(), state :: map()} | {:halt, Plug.Conn.t()}
```

# `start_link`

Starts a WebSocket handler.

# `upgrade`

Upgrades an HTTP connection to WebSocket.

This initiates the Cowboy WebSocket upgrade handshake. The `handler` module
must `use Hibana.WebSocket` and implement the required callbacks.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
