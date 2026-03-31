defmodule Hibana.Endpoint do
  @moduledoc """
  HTTP endpoint module that starts the Cowboy HTTP server.

  ## Usage

      defmodule MyApp.Endpoint do
        use Hibana.Endpoint, otp_app: :my_app
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
  """

  defmacro __using__(opts) do
    quote do
      use Plug.Builder

      plug(Hibana.Plug.Defaults)

      @doc false
      def start_link(start_opts \\ []) do
        Hibana.Endpoint.start_link(__MODULE__, start_opts, unquote(opts))
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

  ## Parameters

    - `opts` - Options passed through unchanged

  ## Returns

  The options unchanged.
  """
  @spec init(any()) :: any()
  def init(opts), do: opts

  @doc """
  Starts the Cowboy HTTP server for the given plug module.

  Reads configuration from the application environment using the `:otp_app`
  option. Supports `:http` options for IP and port binding. Returns `:ignore`
  if `:start_server` is set to `false` in the `:hibana` config (useful for tests).

  The server PID is registered under `Hibana.Endpoint.Server` for graceful shutdown.

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
      Hibana.Endpoint.start_link(MyApp.Endpoint, [], otp_app: :my_app)
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

      {http_opts, config} = Keyword.pop(config, :http, [])
      {ref, _config} = Keyword.pop(config, :ref, plug_module)

      http_options = [
        ip: Keyword.get(http_opts, :ip, {0, 0, 0, 0}),
        port: Keyword.get(http_opts, :port, 4000)
      ]

      case Plug.Cowboy.http(plug_module, [], http_options ++ [ref: ref]) do
        {:error, :eaddrinuse} ->
          {:error, :address_in_use}

        {:ok, pid} = result ->
          # Register server PID for graceful shutdown
          Process.register(pid, Hibana.Endpoint.Server)
          result

        result ->
          result
      end
    end
  end

  @doc """
  Returns a child specification for use in a supervision tree.

  ## Parameters

    - `opts` - Options passed to `start_link/3`

  ## Returns

  A child spec map with `:id`, `:start`, `:type`, `:restart`, and `:shutdown` keys.

  ## Examples

      ```elixir
      children = [
        Hibana.Endpoint
      ]
      Supervisor.start_link(children, strategy: :one_for_one)
      ```
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
