defmodule Hibana.LiveView do
  @moduledoc """
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
          "<div><h1>Count: \#{assigns[:count]}</h1></div>"
        end

        def handle_event("increment", _params, socket) do
          {:noreply, assign(socket, count: socket.assigns.count + 1)}
        end
      end

  """

  defmodule Socket do
    @moduledoc """
    The LiveView socket struct that holds state, assigns, and connection metadata.

    ## Fields

    | Field | Type | Description |
    |-------|------|-------------|
    | `:assigns` | `map()` | User-defined state (via `assign/2` and `assign/3`) |
    | `:endpoint` | `module()` | The Hibana endpoint module |
    | `:handler` | `module()` | The LiveView handler module |
    | `:id` | `String.t()` | Unique socket identifier |
    | `:connected?` | `boolean()` | Whether WebSocket handshake is complete |
    """

    defstruct [:assigns, :endpoint, :handler, :id, :connected?]

    @doc """
    Creates a new LiveView socket.

    ## Parameters

      - `handler` - The LiveView handler module
      - `endpoint` - The endpoint module
      - `id` - Optional socket ID (default: auto-generated)

    ## Returns

    A new `Socket` struct with empty assigns.
    """
    def new(handler, endpoint, id \\ nil) do
      %__MODULE__{
        assigns: %{},
        endpoint: endpoint,
        handler: handler,
        id: id || generate_id(),
        connected?: false
      }
    end

    @doc """
    Assigns a single key-value pair to the socket.

    ## Parameters

      - `socket` - The socket struct
      - `key` - An atom key
      - `value` - The value to assign

    ## Returns

    The socket with the updated assigns.
    """
    def assign(socket, key, value) when is_atom(key) do
      %{socket | assigns: Map.put(socket.assigns, key, value)}
    end

    @doc """
    Assigns multiple key-value pairs from a keyword list to the socket.

    ## Parameters

      - `socket` - The socket struct
      - `keyword_list` - A keyword list of assigns

    ## Returns

    The socket with the updated assigns.
    """
    def assign(socket, keyword_list) when is_list(keyword_list) do
      Enum.reduce(keyword_list, socket, fn {key, value}, acc ->
        assign(acc, key, value)
      end)
    end

    def assign(socket, %{__assigns__: _} = assigns) do
      %{socket | assigns: Map.merge(socket.assigns, Map.from_struct(assigns))}
    end

    @doc """
    Pushes an event with a payload to the client.

    ## Parameters

      - `socket` - The socket struct
      - `event` - The event name string
      - `payload` - The event payload
    """
    def push_event(socket, event, payload) do
      %{socket | assigns: Map.put(socket.assigns, :"phx-#{event}", payload)}
    end

    defp generate_id do
      :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
    end
  end

  @doc """
  Called when LiveView is mounted. Return {:ok, socket} or {:error, reason}.
  """
  @callback mount(params :: map(), session :: map(), socket :: Socket.t()) ::
              {:ok, Socket.t()} | {:ok, Socket.t(), keyword()} | {:error, any()}

  @doc """
  Renders the LiveView template. Must return HTML string.
  """
  @callback render(assigns :: map()) :: String.t()

  @doc """
  Handle incoming events from client (phx-click, phx-submit, etc.)
  """
  @callback handle_event(event :: String.t(), params :: map(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:reply, map(), Socket.t()}
              | {:stop, Socket.t()}

  @doc """
  Handle incoming info messages (from GenServer, etc.)
  """
  @callback handle_info(msg :: any(), socket :: Socket.t()) ::
              {:noreply, Socket.t()}
              | {:stop, Socket.t()}

  @doc """
  Handle websocket connection
  """
  @callback handle_connect(socket :: Socket.t()) :: {:ok, Socket.t()}

  @doc """
  Called when LiveView is being terminated
  """
  @callback terminate(reason :: any(), socket :: Socket.t()) :: :ok

  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour Hibana.LiveView

      import Hibana.LiveView
      import Hibana.LiveView.Socket, only: [assign: 2, assign: 3]
      alias Hibana.LiveView.Socket

      def mount(_params, _session, socket) do
        {:ok, socket}
      end

      def render(assigns) do
        ""
      end

      def handle_event(_event, _params, socket) do
        {:noreply, socket}
      end

      def handle_info(_msg, socket) do
        {:noreply, socket}
      end

      def handle_connect(socket) do
        {:ok, socket}
      end

      def terminate(_reason, _socket) do
        :ok
      end

      defoverridable mount: 3,
                     render: 1,
                     handle_event: 3,
                     handle_info: 2,
                     handle_connect: 1,
                     terminate: 2
    end
  end

  @doc """
  Creates a new LiveView socket.
  """
  def socket(handler, endpoint, id \\ nil) do
    Socket.new(handler, endpoint, id)
  end

  @doc """
  Marks socket as connected (after WebSocket handshake).
  """
  def connected(socket) do
    %{socket | connected?: true}
  end

  @doc """
  Pushes an event to the client.
  """
  def push(socket, event, payload \\ %{}) do
    %{socket | assigns: Map.put(socket.assigns, :"phx-#{event}", payload)}
  end

  @doc """
  Redirects to a different URL.
  """
  def redirect(socket, to: url) do
    %{socket | assigns: Map.put(socket.assigns, :__redirect__, url)}
  end

  @doc """
  Renders a template with assigns.
  """
  def render_template(template_fun) when is_function(template_fun, 1) do
    fn assigns -> template_fun.(assigns) end
  end
end
