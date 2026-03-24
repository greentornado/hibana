defmodule Hibana.WebSocket do
  @moduledoc """
  WebSocket handler behaviour for Hibana.

  Provides a behaviour with callbacks for handling WebSocket connections,
  messages, and disconnections. Uses Cowboy's native WebSocket support
  for microsecond-level latency.

  ## Features

  - Direct Cowboy WebSocket integration with zero middleware overhead
  - Text and binary message handling
  - Process message forwarding via `handle_info/2`
  - Automatic connection/disconnection lifecycle management

  ## Usage

      defmodule MyApp.ChatSocket do
        use Hibana.WebSocket

        def handle_in(msg, state) do
          {:reply, {:text, "echo: \#{msg}"}, state}
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

  ## Callbacks

  | Callback | Description |
  |----------|-------------|
  | `init/2` | Called on connection upgrade |
  | `handle_connect/2` | Called after WebSocket handshake |
  | `handle_in/2` | Called for text messages |
  | `handle_binary/2` | Called for binary messages |
  | `handle_info/2` | Called for Erlang process messages |
  | `handle_disconnect/2` | Called on connection close |

  ## Return Values

  Callbacks return tuples:

  - `{:ok, state}` - Continue with updated state
  - `{:reply, {:text, data}, state}` - Send a text frame
  - `{:reply, {:binary, data}, state}` - Send a binary frame
  - `{:push, {:text, data}, state}` - Push from `handle_info`
  - `{:stop, state}` - Close the connection
  """

  alias Hibana.Endpoint
  import Plug.Conn

  @callback init(conn :: Plug.Conn.t(), opts :: any()) ::
              {:ok, Plug.Conn.t(), state :: map()}
              | {:halt, Plug.Conn.t()}

  @callback handle_connect(info :: any(), state :: map()) :: {:ok, map()} | {:stop, map()}

  @callback handle_disconnect(reason :: any(), state :: map()) :: {:ok, map()}

  @callback handle_in(message :: String.t(), state :: map()) ::
              {:ok, map()}
              | {:reply, reply :: any(), map()}
              | {:stop, map()}

  @callback handle_binary(message :: binary(), state :: map()) ::
              {:ok, map()}
              | {:reply, reply :: any(), map()}
              | {:stop, map()}

  @callback handle_info(message :: any(), state :: map()) ::
              {:ok, map()}
              | {:push, push :: any(), map()}
              | {:stop, map()}

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Hibana.WebSocket

      def init(conn, _opts) do
        {:ok, conn, %{}}
      end

      def handle_connect(_info, state) do
        {:ok, state}
      end

      def handle_disconnect(_reason, state) do
        {:ok, state}
      end

      def handle_in(message, state) do
        {:ok, state}
      end

      def handle_binary(_message, state) do
        {:ok, state}
      end

      def handle_info(_message, state) do
        {:ok, state}
      end

      defoverridable init: 2,
                     handle_connect: 2,
                     handle_disconnect: 2,
                     handle_in: 2,
                     handle_binary: 2,
                     handle_info: 2
    end
  end

  @doc """
  Starts a WebSocket handler via the Hibana endpoint.

  ## Parameters

    - `handler` - The WebSocket handler module
    - `opts` - Options passed to the endpoint (default: `[]`)

  ## Returns

  The result of `Hibana.Endpoint.start_link/1`.
  """
  def start_link(handler, opts \\ []) do
    Endpoint.start_link(Keyword.merge(opts, handler: handler))
  end

  @doc """
  Upgrades an HTTP connection to a WebSocket connection.

  Initiates the Cowboy WebSocket upgrade handshake. The `handler` module
  must `use Hibana.WebSocket` and implement the required callbacks.

  ## Parameters

    - `conn` - The `Plug.Conn` struct from an HTTP request
    - `handler` - The WebSocket handler module (must `use Hibana.WebSocket`)
    - `handler_opts` - Options passed to the handler's `init/2` callback (default: `[]`)

  ## Returns

  The connection after initiating the WebSocket upgrade.

  ## Examples

      ```elixir
      def websocket(conn) do
        Hibana.WebSocket.upgrade(conn, MyApp.ChatSocket)
      end

      def websocket(conn) do
        Hibana.WebSocket.upgrade(conn, MyApp.ChatSocket, room: "lobby")
      end
      ```
  """
  def upgrade(conn, handler, handler_opts \\ []) do
    conn
    |> put_private(:websocket_handler, handler)
    |> put_private(:websocket_handler_opts, handler_opts)
    |> upgrade_adapter(
      :websocket,
      {Hibana.WebSocket.CowboyAdapter, {handler, handler_opts}, %{idle_timeout: 60_000}}
    )
  end
end
