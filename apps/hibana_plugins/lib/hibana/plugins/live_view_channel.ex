defmodule Hibana.Plugins.LiveView do
  @moduledoc """
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
          "<div>Count: \#{assigns[:count]}</div>"
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
  """

  use Hibana.Plugin
  import Plug.Conn
  alias Hibana.WebSocket

  @impl true
  def init(opts) do
    %{
      handler: Keyword.get(opts, :handler)
    }
  end

  @impl true
  def call(conn, %{handler: handler}) do
    case conn.path_info do
      ["lv", "socket" | _] ->
        case get_req_header(conn, "upgrade") do
          ["websocket" | _] ->
            WebSocket.upgrade(conn, handler, [])

          _ ->
            conn
            |> put_resp_content_type("text/html")
            |> send_resp(426, "Upgrade required")
            |> halt()
        end

      _ ->
        conn
    end
  end

  @doc """
  Builds a new LiveView socket for the given handler module.

  ## Parameters

    - `handler` - The LiveView handler module
    - `endpoint` - The endpoint module
    - `id` - Optional socket ID (default: auto-generated)

  ## Returns

  A `Hibana.LiveView.Socket` struct.
  """
  def build_socket(handler, endpoint, id \\ nil) do
    Hibana.LiveView.Socket.new(handler, endpoint, id)
  end

  @doc """
  Dispatches an event to the LiveView handler.

  ## Parameters

    - `socket` - The LiveView socket
    - `event` - The event name string
    - `params` - Event parameters map
    - `handler` - The handler module

  ## Returns

  The result of the handler's `handle_event/3` callback.
  """
  def handle_event(socket, event, params, handler) do
    handler.handle_event(event, params, socket)
  end

  @doc """
  Renders the LiveView template using the handler's `render/1` callback.

  ## Parameters

    - `socket` - The LiveView socket
    - `handler` - The handler module

  ## Returns

  An HTML string.
  """
  def render(socket, handler) do
    handler.render(socket.assigns)
  end
end
