defmodule Hibana.WebSocket do
  @moduledoc """
  WebSocket handler behavior for Hibana.

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
  Starts a WebSocket handler.
  """
  def start_link(handler, opts \\ []) do
    Endpoint.start_link(Keyword.merge(opts, handler: handler))
  end

  @doc """
  Upgrades an HTTP connection to WebSocket.

  This initiates the Cowboy WebSocket upgrade handshake. The `handler` module
  must `use Hibana.WebSocket` and implement the required callbacks.
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
