defmodule Hibana.BanditEndpoint do
  @moduledoc """
  HTTP endpoint module that starts the Bandit HTTP server.

  Bandit is a modern, pure-Elixir HTTP server with excellent performance
  and full Plug and WebSocket support.

  ## Usage

      defmodule MyApp.Endpoint do
        use Hibana.BanditEndpoint, otp_app: :my_app
      end

  ## Configuration

  Add to your config:

      config :my_app, MyApp.Endpoint,
        http: [ip: {0, 0, 0, 0}, port: 4000],
        secret_key_base: "your-secret-key-base-at-least-64-bytes-long"

  ## Starting the Endpoint

  The endpoint is typically started as part of your application supervision tree:

      defmodule MyApp do
        use Application

        def start(_type, _args) do
          children = [MyApp.Endpoint]
          Supervisor.start_link(children, strategy: :one_for_one)
        end
      end

  ## Child Spec

  The endpoint implements the `child_spec/1` callback for use in supervision trees:

      Supervisor.child_spec({MyApp.Endpoint, []})

  ## Bandit vs Cowboy

  | Feature | Bandit | Cowboy |
  |---------|--------|--------|
  | Language | Pure Elixir | Erlang |
  | HTTP/2 | Native | Via Plug |
  | WebSocket | Native | Native |
  | Performance | Excellent | Good |
  | Memory | Lower | Higher |

  Bandit is recommended for new projects. Cowboy is kept for compatibility.
  """

  defmacro __using__(opts) do
    quote do
      use Plug.Builder

      plug(Hibana.Plug.Defaults)

      @doc false
      def start_link(start_opts \\ []) do
        Hibana.BanditEndpoint.start_link(__MODULE__, start_opts, unquote(opts))
      end

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 500
        }
      end

      defoverridable start_link: 1, child_spec: 1
    end
  end

  use Plug.Builder, plug: Hibana.Plug.Defaults

  plug(Hibana.Router)

  @doc """
  Initializes the endpoint plug with the given options.
  """
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc """
  Starts the Bandit HTTP server for the given plug module.

  Reads configuration from the application environment using the `:otp_app`
  option. Returns `:ignore` if `:start_server` is set to `false` in the `:hibana`
  config (useful for tests).

  ## Parameters

    - `plug_module` - The plug module to serve (default: `__MODULE__`)
    - `opts` - Additional options merged with app config (default: `[]`)
    - `app_opts` - Application-level options including `:otp_app` (default: `[]`)

  ## Returns

    - `{:ok, pid}` on success
    - `{:error, :address_in_use}` if the port is already bound
    - `:ignore` if server startup is disabled

  ## Examples

      ```elixir
      Hibana.BanditEndpoint.start_link(MyApp.Endpoint, [], otp_app: :my_app)
      ```
  """
  def start_link(plug_module \\ __MODULE__, opts \\ [], app_opts \\ []) do
    if Application.get_env(:hibana, :start_server, true) == false do
      :ignore
    else
      otp_app = Keyword.get(app_opts, :otp_app, :hibana)

      config =
        (Application.get_env(otp_app, plug_module) || [])
        |> Keyword.merge(opts)

      {http_opts, _config} = Keyword.pop(config, :http, [])

      http_options = [
        ip: Keyword.get(http_opts, :ip, {127, 0, 0, 1}),
        port: Keyword.get(http_opts, :port, 4000)
      ]

      bandit_opts = [
        plug: plug_module,
        scheme: :http,
        options: http_options
      ]

      case Bandit.start_link(bandit_opts) do
        {:error, :eaddrinuse} -> {:error, :address_in_use}
        result -> result
      end
    end
  end

  @doc """
  Returns a child specification for use in a supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end
end
