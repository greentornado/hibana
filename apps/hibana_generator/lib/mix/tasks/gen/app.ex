defmodule Mix.Tasks.Gen.App do
  use Mix.Task

  @shortdoc "Generate a new Hibana application"

  @moduledoc """
  Generates a new Hibana application.

      mix gen.app my_app
      mix gen.app /path/to/my_app

  Creates:
  - `lib/my_app/endpoint.ex`
  - `lib/my_app/router.ex`
  - `lib/my_app/application.ex`
  - `config/config.exs`
  - `mix.exs`

  ## Options

  - `--skip-git` - Skip git initialization
  - `--hibana-path` - Path to the Hibana umbrella (default: auto-detect)

  ## Examples

      mix gen.app my_app
      mix gen.app ~/projects/my_app
  """

  @impl true
  def run(args) do
    {opts, args, _} = OptionParser.parse(args, switches: [skip_git: :boolean, hibana_path: :string])

    case args do
      [path | _] ->
        generate_app(path, opts)

      _ ->
        Mix.raise("Usage: mix gen.app <app_name_or_path> [--skip-git] [--hibana-path PATH]")
    end
  end

  defp generate_app(path, opts) do
    app_path = Path.expand(path)
    app_name = Path.basename(app_path) |> Macro.underscore()
    app_module = Macro.camelize(app_name)

    if File.exists?(app_path) do
      Mix.raise("Directory #{app_path} already exists")
    end

    hibana_path = detect_hibana_path(app_path, opts)

    Mix.shell().info("Generating #{app_name}...")

    # Create directory structure (snake_case)
    File.mkdir_p!("#{app_path}/lib/#{app_name}")
    File.mkdir_p!("#{app_path}/config")
    File.mkdir_p!("#{app_path}/test")

    create_mix_exs(app_path, app_name, app_module, hibana_path)
    create_config(app_path, app_name, app_module)
    create_endpoint(app_path, app_name, app_module)
    create_router(app_path, app_name, app_module)
    create_application(app_path, app_name, app_module)
    create_gitignore(app_path)

    unless opts[:skip_git] do
      init_git(app_path)
    end

    Mix.shell().info("""

    Done! Your app is ready at #{app_path}

    To get started:
      cd #{app_name}
      mix deps.get
      mix run --no-halt

    Then visit http://localhost:4000
    """)
  end

  defp detect_hibana_path(_app_path, opts) do
    case Keyword.get(opts, :hibana_path) do
      nil ->
        # Try to find hibana apps directory
        cwd = File.cwd!()

        candidates = [
          # Running from umbrella root
          Path.join(cwd, "apps/hibana"),
          # Running from within apps/ directory
          Path.join(cwd, "../hibana") |> Path.expand(),
          # Running from an app within apps/
          Path.join(cwd, "../../apps/hibana") |> Path.expand()
        ]

        case Enum.find(candidates, &File.exists?/1) do
          nil -> nil
          hibana_app_path -> Path.dirname(hibana_app_path) |> Path.expand()
        end

      path ->
        Path.expand(path)
    end
  end

  defp create_mix_exs(path, app_name, app_module, hibana_path) do
    deps =
      if hibana_path do
        """
            [
              {:hibana, path: "#{hibana_path}/hibana"},
              {:hibana_plugins, path: "#{hibana_path}/hibana_plugins"}
            ]
        """
      else
        """
            [
              {:plug, "~> 1.16"},
              {:plug_cowboy, "~> 2.7"},
              {:jason, "~> 1.4"}
            ]
        """
      end

    content = """
    defmodule #{app_module}.MixProject do
      use Mix.Project

      def project do
        [
          app: :#{app_name},
          version: "0.1.0",
          elixir: "~> 1.15",
          start_permanent: Mix.env() == :prod,
          deps: deps()
        ]
      end

      def application do
        [
          extra_applications: [:logger],
          mod: {#{app_module}.Application, []}
        ]
      end

      defp deps do
    #{String.trim(deps)}
      end
    end
    """

    File.write!("#{path}/mix.exs", content)
  end

  defp create_config(path, app_name, app_module) do
    secret = Base.encode64(:crypto.strong_rand_bytes(48))

    content = """
    import Config

    config :#{app_name}, #{app_module}.Endpoint,
      http: [ip: {0, 0, 0, 0}, port: 4000]

    config :#{app_name},
      secret_key_base: "#{secret}"

    config :logger, :console,
      format: "$time $metadata[$level] $message\\n",
      level: :info
    """

    File.write!("#{path}/config/config.exs", content)
  end

  defp create_endpoint(path, app_name, app_module) do
    content =
      if hibana_available?() do
        """
        defmodule #{app_module}.Endpoint do
          use Hibana.Endpoint, otp_app: :#{app_name}

          plug Hibana.Plugins.RequestId
          plug Hibana.Plugins.Logger
          plug #{app_module}.Router
        end
        """
      else
        """
        defmodule #{app_module}.Endpoint do
          use Plug.Builder

          plug Plug.Logger
          plug #{app_module}.Router

          def start_link(_opts \\\\ []) do
            port = Application.get_env(:#{app_name}, :port, 4000)

            IO.puts("\\n  Hibana server running at http://localhost:\#{port}\\n")
            Plug.Cowboy.http(__MODULE__, [], port: port)
          end

          def child_spec(opts) do
            %{
              id: __MODULE__,
              start: {__MODULE__, :start_link, [opts]},
              type: :worker,
              restart: :permanent
            }
          end
        end
        """
      end

    File.write!("#{path}/lib/#{app_name}/endpoint.ex", content)
  end

  defp create_router(path, app_name, app_module) do
    content =
      if hibana_available?() do
        """
        defmodule #{app_module}.Router do
          use Hibana.Router.DSL

          plug Hibana.Plugins.BodyParser

          get "/", #{app_module}.PageController, :index
          get "/hello/:name", #{app_module}.PageController, :hello
        end
        """
      else
        """
        defmodule #{app_module}.Router do
          use Plug.Router

          plug :match
          plug Plug.Parsers, parsers: [:json], json_decoder: Jason
          plug :dispatch

          get "/" do
            send_resp(conn, 200, Jason.encode!(%{message: "Welcome to #{app_module}!", status: "running"}))
          end

          get "/hello/:name" do
            send_resp(conn, 200, Jason.encode!(%{hello: name}))
          end

          match _ do
            send_resp(conn, 404, Jason.encode!(%{error: "Not Found"}))
          end
        end
        """
      end

    File.write!("#{path}/lib/#{app_name}/router.ex", content)

    # Create controller if using Hibana
    if hibana_available?() do
      create_page_controller(path, app_name, app_module)
    end
  end

  defp create_page_controller(path, app_name, app_module) do
    content = """
    defmodule #{app_module}.PageController do
      use Hibana.Controller

      def index(conn, _params) do
        json(conn, %{message: "Welcome to #{app_module}!", status: "running"})
      end

      def hello(conn, %{"name" => name}) do
        json(conn, %{hello: name})
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/page_controller.ex", content)
  end

  defp create_application(path, app_name, app_module) do
    content = """
    defmodule #{app_module}.Application do
      use Application

      @impl true
      def start(_type, _args) do
        children = [
          #{app_module}.Endpoint
        ]

        opts = [strategy: :one_for_one, name: #{app_module}.Supervisor]
        Supervisor.start_link(children, opts)
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/application.ex", content)
  end

  defp create_gitignore(path) do
    content = """
    /_build/
    /deps/
    erl_crash.dump
    *.ez
    *.beam
    .elixir_ls/
    """

    File.write!("#{path}/.gitignore", content)
  end

  defp init_git(path) do
    File.cd!(path, fn ->
      Mix.shell().info("Initializing git repository...")
      System.cmd("git", ["init", "-q"])
      System.cmd("git", ["add", "-A"])
      System.cmd("git", ["commit", "-q", "-m", "Initial commit"])
    end)
  end

  defp hibana_available? do
    Code.ensure_loaded?(Hibana.Endpoint)
  end
end
