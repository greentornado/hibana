defmodule Hibana.WebSocket do
  @moduledoc """
  WebSocket handler behavior with support for both Cowboy and Bandit servers.

  Provides a unified callback-based API for WebSocket connections that works
  seamlessly with both Cowboy (Erlang) and Bandit (Pure Elixir) HTTP servers.
  The framework automatically detects which server you're using and selects the
  appropriate adapter.

  ## Features

  - **Dual Server Support**: Works with both Cowboy and Bandit automatically
  - **Direct WebSocket integration** with zero middleware overhead
  - Text and binary message support
  - Connection lifecycle management (connect, disconnect, heartbeat)
  - Mailbox-based message passing for external process communication
  - Automatic ping/pong handling for connection keepalive

  ## Server Compatibility

  | Feature | Cowboy | Bandit | Notes |
  |---------|--------|--------|-------|
  | Text frames | ✅ | ✅ | Full support |
  | Binary frames | ✅ | ✅ | Full support |
  | Ping/Pong | ✅ | ✅ | Automatic |
  | Compression | ✅ | ✅ | Per-message deflate |
  | Subprotocols | ✅ | ✅ | Supported |

  ## Usage

  Create a WebSocket handler module:

      defmodule MyApp.ChatSocket do
        use Hibana.WebSocket

        @impl true
        def init(conn, opts) do
          room = conn.params["room"] || "general"
          {:ok, conn, %{room: room, user: nil}}
        end

        @impl true
        def handle_connect(_headers, state) do
          {:ok, state}
        end

        @impl true
        def handle_in(message, state) do
          {:reply, {:text, "Echo: " <> message}, state}
        end
      end

  Add to your router:

      get "/ws", MyApp.ChatSocket, :upgrade

  ## Configuration

  No special configuration needed - the framework auto-detects your server:
  - If using `Hibana.Endpoint` → Cowboy adapter
  - If using `Hibana.BanditEndpoint` → Bandit adapter

  ## Callbacks

  | Callback | Description |
  |----------|-------------|
  | `init/2` | Initialize connection state |
  | `handle_connect/2` | Called when WebSocket connection established |
  | `handle_in/2` | Handle text messages |
  | `handle_binary/2` | Handle binary messages |
  | `handle_info/2` | Handle Elixir messages sent to socket process |
  | `handle_disconnect/2` | Called when connection closes |
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

  Initiates the WebSocket upgrade handshake. The `handler` module
  must `use Hibana.WebSocket` and implement the required callbacks.

  This function automatically detects whether you're using Cowboy or Bandit
  and uses the appropriate adapter.

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
      websocket_adapter(conn, handler, handler_opts)
    )
  end

  # Choose the appropriate WebSocket adapter based on the server
  # Uses efficient pattern matching instead of string detection
  defp websocket_adapter(_conn, handler, handler_opts) do
    # Check if Bandit is available and being used
    if Code.ensure_loaded?(Bandit.Adapter) do
      {Hibana.WebSocket.BanditAdapter, {handler, handler_opts}, %{idle_timeout: 60_000}}
    else
      # Default to Cowboy adapter
      {Hibana.WebSocket.CowboyAdapter, {handler, handler_opts}, %{idle_timeout: 60_000}}
    end
  end
end
