defmodule Mix.Tasks.Gen.App do
  use Mix.Task

  @shortdoc "Generate a new Hibana application with smart templates"

  @moduledoc """
  Generates a new Hibana application with smart templates and fancy output.

      mix gen.app my_app
      mix gen.app my_app --template api
      mix gen.app my_app --template full --bandit

  ## Templates

  - `api` - REST API with JSON endpoints
  - `full` - Full web app with HTML templates
  - `realtime` - WebSocket/LiveView real-time features
  - `minimal` - Bare minimum structure

  ## Options

  - `--template` - Template to use (api|full|realtime|minimal)
  - `--database` - Database (postgres|mysql|sqlite)
  - `--auth` - Auth type (jwt|api_key|none)
  - `--docker` - Include Docker setup
  - `--ci` - Include GitHub Actions CI
  - `--skip-git` - Skip git initialization
  - `--hibana-path` - Path to Hibana umbrella
  - `--bandit` - Use Bandit instead of Cowboy

  ## Examples

      mix gen.app my_app --template api
      mix gen.app my_app --template full --database postgres --auth jwt
      mix gen.app my_app --docker --ci
  """

  # ASCII Art Logo
  @logo """
  ╔══════════════════════════════════════════════════════════╗
  ║                                                          ║
  ║     ██╗  ██╗██╗██████╗  █████╗ ███╗   ██╗ █████╗        ║
  ║     ██║  ██║██║██╔══██╗██╔══██╗████╗  ██║██╔══██╗       ║
  ║     ███████║██║██████╔╝███████║██╔██╗ ██║███████║       ║
  ║     ██╔══██║██║██╔══██╗██╔══██║██║╚██╗██║██╔══██║       ║
  ║     ██║  ██║██║██████╔╝██║  ██║██║ ╚████║██║  ██║       ║
  ║     ╚═╝  ╚═╝╚═╝╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝       ║
  ║                                                          ║
  ║     🚀 Smart App Generator v1.0                         ║
  ╚══════════════════════════════════════════════════════════╝
  """

  # Templates configuration
  @templates %{
    api: %{
      name: "REST API",
      desc: "JSON API with OpenAPI docs",
      features: [:json_api, :cors, :body_parser]
    },
    full: %{
      name: "Full Web App",
      desc: "HTML templates + API + sessions",
      features: [:json_api, :html, :sessions, :static]
    },
    realtime: %{
      name: "Real-time App",
      desc: "WebSockets + LiveView",
      features: [:websocket, :liveview, :json_api]
    },
    minimal: %{name: "Minimal", desc: "Start from scratch", features: []}
  }

  @doc """
  Runs the application generator.
  """
  @impl true
  def run(args) do
    display_logo()

    {opts, positional_args, _} =
      OptionParser.parse(args,
        switches: [
          template: :string,
          database: :string,
          auth: :string,
          docker: :boolean,
          ci: :boolean,
          skip_git: :boolean,
          hibana_path: :string,
          bandit: :boolean,
          yes: :boolean
        ],
        aliases: [
          t: :template,
          d: :database,
          y: :yes
        ]
      )

    case positional_args do
      [app_name | _] ->
        generate_smart_app(app_name, opts)

      _ ->
        display_usage()
        Mix.raise("Usage: mix gen.app <app_name> [options]")
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Logo & UI
  # ─────────────────────────────────────────────────────────────────────────────

  defp display_logo do
    IO.puts(IO.ANSI.cyan() <> @logo <> IO.ANSI.reset())
  end

  defp display_usage do
    IO.puts("""
    #{IO.ANSI.yellow()}Usage:#{IO.ANSI.reset()}
      mix gen.app <app_name> [options]

    #{IO.ANSI.yellow()}Templates:#{IO.ANSI.reset()}
    #{Enum.map(@templates, fn {key, %{name: name, desc: desc}} -> "  #{IO.ANSI.cyan()}#{key}#{IO.ANSI.reset()}#{String.duplicate(" ", 12 - String.length(to_string(key)))} - #{name} (#{desc})" end) |> Enum.join("\n")}

    #{IO.ANSI.yellow()}Examples:#{IO.ANSI.reset()}
      mix gen.app my_app --template api
      mix gen.app my_app --template full --database postgres --auth jwt --docker --ci
    """)
  end

  defp print_step(step, status \\ :pending) do
    icon =
      case status do
        :pending -> "⏳"
        :running -> "🔧"
        :done -> "✅"
        :skip -> "⏭️"
      end

    IO.puts("  #{icon} #{step}")
  end

  defp print_success(message) do
    IO.puts("  #{IO.ANSI.green()}✓#{IO.ANSI.reset()} #{message}")
  end

  defp print_info(message) do
    IO.puts("  #{IO.ANSI.cyan()}ℹ#{IO.ANSI.reset()} #{message}")
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Smart App Generation
  # ─────────────────────────────────────────────────────────────────────────────

  defp generate_smart_app(app_name, opts) do
    app_path = Path.expand(app_name)
    app_module = Macro.camelize(app_name)

    if File.exists?(app_path) do
      Mix.raise("Directory #{app_path} already exists. Remove it or choose a different name.")
    end

    # Select template
    template = select_template(opts[:template])
    template_config = @templates[template]

    # Select database
    database = select_database(opts[:database])

    # Select auth
    auth = select_auth(opts[:auth], template)

    # Build feature list
    features = build_features(template_config.features, database, auth, opts)

    # Display configuration
    display_config(app_name, template, database, auth, features)

    # Confirm generation (skip if --yes flag provided)
    unless opts[:yes] || confirm?("Generate app with these settings?") do
      IO.puts("\n#{IO.ANSI.yellow()}Cancelled by user#{IO.ANSI.reset()}")
      System.halt(0)
    end

    IO.puts("\n#{IO.ANSI.bright()}🚀 Generating #{app_name}...#{IO.ANSI.reset()}\n")

    # Create directory structure
    print_step("Creating directory structure", :running)
    File.mkdir_p!("#{app_path}/lib/#{app_name}")
    File.mkdir_p!("#{app_path}/lib/#{app_name}/controllers")
    if :database in features, do: File.mkdir_p!("#{app_path}/lib/#{app_name}/models")
    File.mkdir_p!("#{app_path}/config")
    File.mkdir_p!("#{app_path}/test")
    if :static in features, do: File.mkdir_p!("#{app_path}/priv/static")
    print_success("Directory structure created")

    # Generate files
    generate_files(app_path, app_name, app_module, opts, features, database, auth)

    # Git initialization
    unless opts[:skip_git] do
      print_step("Initializing git repository", :running)
      init_git(app_path)
      print_success("Git repository initialized")
    end

    # Success message
    display_success_message(app_name, app_path, features)
  end

  defp select_template(nil) do
    IO.puts("\n#{IO.ANSI.bright()}📦 Select a template:#{IO.ANSI.reset()}")

    @templates
    |> Enum.with_index(1)
    |> Enum.each(fn {{key, %{name: name, desc: desc}}, idx} ->
      IO.puts(
        "  #{IO.ANSI.cyan()}#{idx}.#{IO.ANSI.reset()} #{IO.ANSI.bright()}#{name}#{IO.ANSI.reset()}"
      )

      IO.puts("     #{IO.ANSI.light_black()}#{desc}#{IO.ANSI.reset()}")
    end)

    case IO.gets("\n#{IO.ANSI.yellow()}→#{IO.ANSI.reset()} Select (1-4): ") |> String.trim() do
      "1" -> :api
      "2" -> :full
      "3" -> :realtime
      "4" -> :minimal
      "" -> :api
      _ -> select_template(nil)
    end
  end

  defp select_template(template_str) do
    case String.to_atom(template_str) do
      t when t in [:api, :full, :realtime, :minimal] -> t
      _ -> :api
    end
  end

  defp select_database(nil) do
    IO.puts("\n#{IO.ANSI.bright()}🗄️  Select database:#{IO.ANSI.reset()}")
    IO.puts("  #{IO.ANSI.cyan()}1.#{IO.ANSI.reset()} PostgreSQL")
    IO.puts("  #{IO.ANSI.cyan()}2.#{IO.ANSI.reset()} MySQL")
    IO.puts("  #{IO.ANSI.cyan()}3.#{IO.ANSI.reset()} SQLite")
    IO.puts("  #{IO.ANSI.cyan()}4.#{IO.ANSI.reset()} None (no database)")

    case IO.gets("\n#{IO.ANSI.yellow()}→#{IO.ANSI.reset()} Select (1-4): ") |> String.trim() do
      "1" -> :postgres
      "2" -> :mysql
      "3" -> :sqlite
      "4" -> :none
      "" -> :postgres
      _ -> select_database(nil)
    end
  end

  defp select_database(db_str), do: String.to_atom(db_str || "none")

  defp select_auth(nil, template) do
    if template in [:api, :full, :realtime] do
      IO.puts("\n#{IO.ANSI.bright()}🔐 Select authentication:#{IO.ANSI.reset()}")
      IO.puts("  #{IO.ANSI.cyan()}1.#{IO.ANSI.reset()} JWT Tokens")
      IO.puts("  #{IO.ANSI.cyan()}2.#{IO.ANSI.reset()} API Keys")
      IO.puts("  #{IO.ANSI.cyan()}3.#{IO.ANSI.reset()} None")

      case IO.gets("\n#{IO.ANSI.yellow()}→#{IO.ANSI.reset()} Select (1-3): ") |> String.trim() do
        "1" -> :jwt
        "2" -> :api_key
        "3" -> :none
        "" -> :jwt
        _ -> select_auth(nil, template)
      end
    else
      :none
    end
  end

  defp select_auth(auth_str, _), do: String.to_atom(auth_str || "none")

  defp build_features(base_features, database, auth, opts) do
    features = base_features
    features = if database != :none, do: [:database | features], else: features
    features = if auth != :none, do: [:auth | features], else: features
    features = if opts[:docker], do: [:docker | features], else: features
    features = if opts[:ci], do: [:ci | features], else: features
    features
  end

  defp display_config(app_name, template, database, auth, features) do
    IO.puts("""

    #{IO.ANSI.yellow()}📋 Configuration:#{IO.ANSI.reset()}
    #{IO.ANSI.light_black()}─────────────────────────────────────#{IO.ANSI.reset()}

      #{IO.ANSI.green()}App Name:#{IO.ANSI.reset()} #{app_name}
      #{IO.ANSI.green()}Template:#{IO.ANSI.reset()} #{@templates[template].name}
      #{IO.ANSI.green()}Database:#{IO.ANSI.reset()} #{format_database(database)}
      #{IO.ANSI.green()}Auth:#{IO.ANSI.reset()} #{format_auth(auth)}
      #{IO.ANSI.green()}Features:#{IO.ANSI.reset()} #{Enum.join(Enum.map(features, &to_string/1), ", ")}
    """)
  end

  defp format_database(:postgres), do: "PostgreSQL"
  defp format_database(:mysql), do: "MySQL"
  defp format_database(:sqlite), do: "SQLite"
  defp format_database(:none), do: "None"

  defp format_auth(:jwt), do: "JWT Tokens"
  defp format_auth(:api_key), do: "API Keys"
  defp format_auth(:none), do: "None"

  defp confirm?(prompt) do
    case IO.gets("#{prompt} #{IO.ANSI.light_black()}[Y/n]:#{IO.ANSI.reset()} ")
         |> String.trim()
         |> String.downcase() do
      "" -> true
      "y" -> true
      "yes" -> true
      "n" -> false
      "no" -> false
      _ -> confirm?(prompt)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # File Generation
  # ─────────────────────────────────────────────────────────────────────────────

  defp generate_files(app_path, app_name, app_module, opts, features, database, auth) do
    hibana_path = detect_hibana_path(app_path, opts)

    print_step("Generating mix.exs", :running)
    create_mix_exs(app_path, app_name, app_module, hibana_path, opts, features, database)
    print_success("mix.exs created")

    print_step("Generating configuration files", :running)
    create_config_files(app_path, app_name, app_module, database)
    print_success("Configuration files created")

    print_step("Generating endpoint", :running)
    create_endpoint(app_path, app_name, app_module, opts, features)
    print_success("Endpoint created")

    print_step("Generating router", :running)
    create_router(app_path, app_name, app_module, features, auth)
    print_success("Router created")

    print_step("Generating application module", :running)
    create_application(app_path, app_name, app_module, features)
    print_success("Application module created")

    if :database in features do
      print_step("Generating database files", :running)
      create_database_files(app_path, app_name, app_module, database)
      print_success("Database files created")
    end

    if :auth in features do
      print_step("Generating authentication files", :running)
      create_auth_files(app_path, app_name, app_module, auth)
      print_success("Authentication files created")
    end

    print_step("Generating controllers", :running)
    create_controllers(app_path, app_name, app_module, features)
    print_success("Controllers created")

    if :docker in features do
      print_step("Generating Docker files", :running)
      create_docker_files(app_path, app_name, database)
      print_success("Docker files created")
    end

    if :ci in features do
      print_step("Generating CI/CD workflow", :running)
      create_github_actions(app_path, app_name, database)
      print_success("CI/CD workflow created")
    end

    print_step("Generating README", :running)
    create_readme(app_path, app_name, app_module, features, database, auth, opts)
    print_success("README created")

    print_step("Generating .gitignore", :running)
    create_gitignore(app_path)
    print_success(".gitignore created")
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # mix.exs
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_mix_exs(path, app_name, app_module, hibana_path, opts, features, database) do
    use_bandit = opts[:bandit] || false

    server_dep = if use_bandit, do: "{:bandit, \"~> 1.0\"}", else: "{:plug_cowboy, \"~> 2.7\"}"

    deps = base_deps(hibana_path) ++ [server_dep]

    # Add database deps
    deps = if database == :postgres, do: ["{:postgrex, \"~> 0.17\"}" | deps], else: deps
    deps = if database == :mysql, do: ["{:myxql, \"~> 0.6\"}" | deps], else: deps
    deps = if database == :sqlite, do: ["{:exqlite, \"~> 0.19\"}" | deps], else: deps

    deps_block = deps |> Enum.map(&"      #{&1}") |> Enum.join(",\n")

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
        [
    #{deps_block}
        ]
      end
    end
    """

    File.write!("#{path}/mix.exs", content)
  end

  defp base_deps(nil), do: ["{:plug, \"~> 1.16\"}", "{:jason, \"~> 1.4\"}"]

  defp base_deps(hibana_path) do
    [
      "{:hibana, path: \"#{hibana_path}/hibana\"}",
      "{:hibana_plugins, path: \"#{hibana_path}/hibana_plugins\"}",
      "{:jason, \"~> 1.4\"}"
    ]
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Configuration Files
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_config_files(path, app_name, app_module, database) do
    secret = Base.encode64(:crypto.strong_rand_bytes(48))

    # config/config.exs
    main_config = [
      "import Config",
      "",
      "config :#{app_name}, #{app_module}.Endpoint,",
      "  http: [ip: {0, 0, 0, 0}, port: 4000]",
      "",
      "config :#{app_name},",
      "  secret_key_base: \"#{secret}\""
    ]

    main_config =
      if database != :none do
        main_config ++
          [
            "",
            "# Database configuration",
            "config :#{app_name}, #{app_module}.Repo,",
            "  adapter: #{database_adapter(database)},",
            "  database: \"#{app_name}_dev\",",
            "  hostname: \"localhost\",",
            "  pool_size: 10"
          ]
      else
        main_config
      end

    main_config =
      main_config ++
        [
          "",
          "config :logger, :console,",
          "  format: \"\\$time \\$metadata[\\$level] \\$message\\\\n\",",
          "  level: :info",
          "",
          "import_config \"\\#{Mix.env()}.exs\""
        ]

    File.write!("#{path}/config/config.exs", Enum.join(main_config, "\n"))

    # config/dev.exs
    dev_config = """
    import Config

    config :#{app_name}, #{app_module}.Endpoint,
      http: [ip: {127, 0, 0, 1}, port: 4000],
      code_reloader: true

    config :logger, :console, level: :debug
    """

    File.write!("#{path}/config/dev.exs", dev_config)

    # config/test.exs
    test_config = ["import Config", ""]

    test_config =
      test_config ++
        [
          "config :#{app_name}, #{app_module}.Endpoint,",
          "  http: [ip: {127, 0, 0, 1}, port: 4001],",
          "  server: false",
          ""
        ]

    test_config =
      if database != :none do
        test_config ++
          [
            "config :#{app_name}, #{app_module}.Repo,",
            "  database: \"#{app_name}_test\",",
            "  pool: Ecto.Adapters.SQL.Sandbox",
            ""
          ]
      else
        test_config
      end

    test_config = test_config ++ ["config :logger, :console, level: :warn"]
    File.write!("#{path}/config/test.exs", Enum.join(test_config, "\n"))

    # config/prod.exs
    prod_config = """
    import Config

    config :#{app_name}, #{app_module}.Endpoint,
      http: [ip: {0, 0, 0, 0}, port: System.get_env(\"PORT\", \"4000\") |> String.to_integer()]

    config :logger, :console, level: :info
    """

    File.write!("#{path}/config/prod.exs", prod_config)
  end

  defp database_adapter(:postgres), do: "Ecto.Adapters.Postgres"
  defp database_adapter(:mysql), do: "Ecto.Adapters.MyXQL"
  defp database_adapter(:sqlite), do: "Ecto.Adapters.SQLite3"

  # ─────────────────────────────────────────────────────────────────────────────
  # Endpoint
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_endpoint(path, app_name, app_module, opts, features) do
    use_bandit = opts[:bandit] || false
    endpoint_type = if use_bandit, do: "Hibana.BanditEndpoint", else: "Hibana.Endpoint"

    plugs = generate_plugs(features)

    content =
      if hibana_available?() do
        """
        defmodule #{app_module}.Endpoint do
          @moduledoc \"\"\"
          HTTP Endpoint for #{app_module}.
          \"\"\"

          use #{endpoint_type}, otp_app: :#{app_name}

        #{plugs}
          plug #{app_module}.Router
        end
        """
      else
        # Fallback
        """
        defmodule #{app_module}.Endpoint do
          use Plug.Builder

          plug Plug.Logger
          plug Plug.RequestId
          plug #{app_module}.Router

          def start_link(_opts \\\\ []) do
            port = Application.get_env(:#{app_name}, :port, 4000)
            IO.puts(\"Server running at http://localhost:\#{port}\")
            #{if use_bandit, do: "Bandit.start_link(plug: __MODULE__, port: port)", else: "Plug.Cowboy.http(__MODULE__, [], port: port)"}
          end

          def child_spec(opts) do
            %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}
          end
        end
        """
      end

    File.write!("#{path}/lib/#{app_name}/endpoint.ex", content)
  end

  defp generate_plugs(features) do
    plugs = ["plug Hibana.Plugins.BodyParser"]

    plugs =
      if :cors in features,
        do: ["plug Hibana.Plugins.CORS, origins: [\"*\"]" | plugs],
        else: plugs

    plugs = if :session in features, do: ["plug Hibana.Plugins.Session" | plugs], else: plugs
    plugs = if :static in features, do: ["plug Hibana.Plugins.Static" | plugs], else: plugs
    plugs = if :auth in features, do: ["plug Hibana.Plugins.JWT" | plugs], else: plugs
    plugs = if :json_api in features, do: ["plug Hibana.Plugins.Logger" | plugs], else: plugs

    plugs
    |> Enum.reverse()
    |> Enum.map(&"    #{&1}")
    |> Enum.join("\n")
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Router
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_router(path, app_name, app_module, features, auth) do
    content =
      if hibana_available?() do
        """
        defmodule #{app_module}.Router do
          @moduledoc \"\"\"
          Router for #{app_module}.
          \"\"\"

          use Hibana.Router.DSL

          plug Hibana.Plugins.BodyParser

          get \"/\", #{app_module}.PageController, :index
          get \"/health\", #{app_module}.HealthController, :index

        #{if :auth in features, do: generate_auth_routes(app_module, auth), else: ""}
        #{if :database in features, do: generate_resource_routes(app_module), else: ""}

          match _, #{app_module}.ErrorController, :not_found
        end
        """
      else
        """
        defmodule #{app_module}.Router do
          use Plug.Router

          plug :match
          plug Plug.Parsers, parsers: [:json], json_decoder: Jason
          plug :dispatch

          get \"/\" do
            send_resp(conn, 200, Jason.encode!(%{message: \"Welcome to #{app_module}!\"}))
          end

          get \"/health\" do
            send_resp(conn, 200, Jason.encode!(%{status: \"healthy\"}))
          end

          match _ do
            send_resp(conn, 404, Jason.encode!(%{error: \"Not Found\"}))
          end
        end
        """
      end

    File.write!("#{path}/lib/#{app_name}/router.ex", content)
  end

  defp generate_auth_routes(app_module, auth) do
    """
        # Authentication routes
        scope \"/auth\" do
          post \"/login\", #{app_module}.AuthController, :login
          post \"/register\", #{app_module}.AuthController, :register
          get \"/me\", #{app_module}.AuthController, :me
        end
    """
  end

  defp generate_resource_routes(app_module) do
    """
        # Resource routes
        scope \"/api\" do
          get \"/users\", #{app_module}.UserController, :index
          get \"/users/:id\", #{app_module}.UserController, :show
          post \"/users\", #{app_module}.UserController, :create
          put \"/users/:id\", #{app_module}.UserController, :update
          delete \"/users/:id\", #{app_module}.UserController, :delete
        end
    """
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Application
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_application(path, app_name, app_module, features) do
    children = ["#{app_module}.Endpoint"]
    children = if :database in features, do: ["#{app_module}.Repo" | children], else: children

    children_block =
      children
      |> Enum.map(&"      #{&1}")
      |> Enum.join(",\n")

    content = """
    defmodule #{app_module}.Application do
      @moduledoc \"\"\"
      OTP Application for #{app_module}.
      \"\"\"

      use Application

      @impl true
      def start(_type, _args) do
        children = [
    #{children_block}
        ]

        Supervisor.start_link(children, strategy: :one_for_one, name: #{app_module}.Supervisor)
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/application.ex", content)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Database Files
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_database_files(path, app_name, app_module, database) do
    # Repo module
    repo_content = """
    defmodule #{app_module}.Repo do
      use Ecto.Repo,
        otp_app: :#{app_name},
        adapter: #{database_adapter(database)}
    end
    """

    File.write!("#{path}/lib/#{app_name}/repo.ex", repo_content)

    # User model
    user_model = """
    defmodule #{app_module}.User do
      use Ecto.Schema
      import Ecto.Changeset

      schema \"users\" do
        field :email, :string
        field :password_hash, :string
        field :name, :string
        timestamps()
      end

      def changeset(user, attrs) do
        cast(user, attrs, [:email, :name])
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/models/user.ex", user_model)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Auth Files
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_auth_files(path, app_name, app_module, auth) do
    auth_controller = """
    defmodule #{app_module}.AuthController do
      use Hibana.Controller
      alias #{app_module}.User

      def login(conn, %{\"email\" => email, \"password\" => password}) do
        # TODO: Implement authentication
        json(conn, %{token: \"dummy_token\", email: email})
      end

      def register(conn, params) do
        # TODO: Implement registration
        json(conn, %{message: \"User registered\"})
      end

      def me(conn, _params) do
        json(conn, %{user: %{id: 1, email: \"user@example.com\"}})
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/controllers/auth_controller.ex", auth_controller)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Controllers
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_controllers(path, app_name, app_module, features) do
    # Health controller
    health_ctrl = """
    defmodule #{app_module}.HealthController do
      use Hibana.Controller

      def index(conn, _params) do
        json(conn, %{status: \"healthy\", timestamp: DateTime.utc_now()})
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/controllers/health_controller.ex", health_ctrl)

    # Page controller
    page_ctrl = """
    defmodule #{app_module}.PageController do
      use Hibana.Controller

      def index(conn, _params) do
        json(conn, %{message: \"Welcome to #{app_module}!\"})
      end

      def hello(conn, %{\"name\" => name}) do
        json(conn, %{hello: name})
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/controllers/page_controller.ex", page_ctrl)

    # Error controller
    error_ctrl = """
    defmodule #{app_module}.ErrorController do
      use Hibana.Controller

      def not_found(conn, _params) do
        conn
        |> put_status(404)
        |> json(%{error: \"Not Found\"})
      end
    end
    """

    File.write!("#{path}/lib/#{app_name}/controllers/error_controller.ex", error_ctrl)

    # User controller if database enabled
    if :database in features do
      user_ctrl = """
      defmodule #{app_module}.UserController do
        use Hibana.Controller
        alias #{app_module}.User
        alias #{app_module}.Repo

        def index(conn, _params) do
          users = Repo.all(User)
          json(conn, %{users: users})
        end

        def show(conn, %{\"id\" => id}) do
          case Repo.get(User, id) do
            nil -> conn |> put_status(404) |> json(%{error: \"Not found\"})
            user -> json(conn, %{user: user})
          end
        end

        def create(conn, params) do
          changeset = User.changeset(%User{}, params)
          case Repo.insert(changeset) do
            {:ok, user} -> conn |> put_status(201) |> json(%{user: user})
            {:error, changeset} -> conn |> put_status(422) |> json(%{errors: changeset.errors})
          end
        end

        def update(conn, %{\"id\" => id} = params) do
          case Repo.get(User, id) do
            nil -> conn |> put_status(404) |> json(%{error: \"Not found\"})
            user ->
              changeset = User.changeset(user, params)
              case Repo.update(changeset) do
                {:ok, user} -> json(conn, %{user: user})
                {:error, changeset} -> conn |> put_status(422) |> json(%{errors: changeset.errors})
              end
          end
        end

        def delete(conn, %{\"id\" => id}) do
          case Repo.get(User, id) do
            nil -> conn |> put_status(404) |> json(%{error: \"Not found\"})
            user ->
              Repo.delete!(user)
              json(conn, %{deleted: true})
          end
        end
      end
      """

      File.write!("#{path}/lib/#{app_name}/controllers/user_controller.ex", user_ctrl)
    end
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Docker & CI/CD
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_docker_files(path, app_name, database) do
    dockerfile = """
    # Build stage
    FROM elixir:1.16-alpine AS builder

    WORKDIR /app
    RUN apk add --no-cache build-base git
    RUN mix local.hex --force && mix local.rebar --force

    COPY mix.exs mix.lock ./
    RUN mix deps.get --only prod
    RUN MIX_ENV=prod mix deps.compile

    COPY lib ./lib
    COPY config ./config
    RUN MIX_ENV=prod mix release

    # Runtime stage
    FROM alpine:3.18
    WORKDIR /app
    RUN apk add --no-cache libstdc++ openssl ncurses-libs
    COPY --from=builder /app/_build/prod/rel/#{app_name} ./

    ENV MIX_ENV=prod
    ENV PORT=4000
    EXPOSE 4000
    CMD [\"bin/#{app_name}\", \"start\"]
    """

    File.write!("#{path}/Dockerfile", dockerfile)

    compose = """
    version: '3.8'
    services:
      app:
        build: .
        ports:
          - \"4000:4000\"
        environment:
          - MIX_ENV=prod
          - SECRET_KEY_BASE=change_me_in_production
    """

    File.write!("#{path}/docker-compose.yml", compose)
  end

  defp create_github_actions(path, app_name, database) do
    File.mkdir_p!("#{path}/.github/workflows")

    workflow = """
    name: CI

    on:
      push:
        branches: [main]
      pull_request:
        branches: [main]

    jobs:
      test:
        runs-on: ubuntu-latest
        steps:
          - uses: actions/checkout@v4
          - uses: erlef/setup-beam@v1
            with:
              elixir-version: '1.16'
              otp-version: '26'
          - run: mix deps.get
          - run: mix test
    """

    File.write!("#{path}/.github/workflows/ci.yml", workflow)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # README & Git
  # ─────────────────────────────────────────────────────────────────────────────

  defp create_readme(path, app_name, app_module, features, database, auth, opts) do
    badges = "![Elixir](https://img.shields.io/badge/Elixir-1.16-purple)"

    features_list =
      features
      |> Enum.map(fn f ->
        case f do
          :json_api -> "- ✅ REST API with JSON"
          :database -> "- ✅ #{format_database(database)} database"
          :auth -> "- ✅ #{format_auth(auth)} authentication"
          :docker -> "- ✅ Docker support"
          :ci -> "- ✅ CI/CD with GitHub Actions"
          _ -> "- ✅ #{f}"
        end
      end)
      |> Enum.join("\n")

    readme = """
    # #{app_module}

    #{badges}

    ## Features

    #{features_list}

    ## Quick Start

    ```bash
    cd #{app_name}
    mix deps.get
    #{if database != :none, do: "mix ecto.setup\n", else: ""}mix run --no-halt
    ```

    Visit http://localhost:4000

    ## Development

    ```bash
    mix test
    mix format
    ```
    """

    File.write!("#{path}/README.md", readme)
  end

  defp create_gitignore(path) do
    content = """
    /_build/
    /deps/
    erl_crash.dump
    *.ez
    *.beam
    .elixir_ls/
    .env
    .env.local
    """

    File.write!("#{path}/.gitignore", content)
  end

  defp init_git(path) do
    File.cd!(path, fn ->
      System.cmd("git", ["init", "-q"])
      System.cmd("git", ["add", "-A"])
      System.cmd("git", ["commit", "-q", "-m", "Initial commit"])
    end)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Success Message
  # ─────────────────────────────────────────────────────────────────────────────

  defp display_success_message(app_name, app_path, features) do
    next_steps = [
      "cd #{app_name}",
      "mix deps.get"
    ]

    next_steps = if :database in features, do: next_steps ++ ["mix ecto.setup"], else: next_steps
    next_steps = next_steps ++ ["mix run --no-halt"]

    steps_block =
      next_steps |> Enum.map(&"  #{IO.ANSI.cyan()}#{&1}#{IO.ANSI.reset()}") |> Enum.join("\n")

    IO.puts("""

    #{IO.ANSI.green()}╔══════════════════════════════════════════════════════════╗#{IO.ANSI.reset()}
    #{IO.ANSI.green()}║#{IO.ANSI.reset()}#{IO.ANSI.bright()}  🎉 App created successfully!#{IO.ANSI.reset()}#{String.duplicate(" ", 30)}#{IO.ANSI.green()}║#{IO.ANSI.reset()}
    #{IO.ANSI.green()}╚══════════════════════════════════════════════════════════╝#{IO.ANSI.reset()}

    #{IO.ANSI.yellow()}Next steps:#{IO.ANSI.reset()}
    #{steps_block}

    #{IO.ANSI.cyan()}Happy coding with Hibana! 🚀#{IO.ANSI.reset()}
    """)
  end

  # ─────────────────────────────────────────────────────────────────────────────
  # Helpers
  # ─────────────────────────────────────────────────────────────────────────────

  defp detect_hibana_path(_app_path, opts) do
    case Keyword.get(opts, :hibana_path) do
      nil ->
        cwd = File.cwd!()

        candidates = [
          Path.join(cwd, "apps/hibana"),
          Path.join(cwd, "../hibana"),
          Path.join(cwd, "../../apps/hibana")
        ]

        case Enum.find(candidates, &File.exists?/1) do
          nil -> nil
          path -> Path.dirname(path)
        end

      path ->
        Path.expand(path)
    end
  end

  defp hibana_available? do
    Code.ensure_loaded?(Hibana.Endpoint)
  end
end
