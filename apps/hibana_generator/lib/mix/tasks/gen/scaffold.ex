defmodule Mix.Tasks.Gen.Scaffold do
  use Mix.Task

  @shortdoc "Generate model + controller + routes for a resource"

  @moduledoc """
  Generates a complete CRUD scaffold: model, controller, and route entries.

      mix gen.scaffold User name:string email:string age:integer

  Creates:
  - `lib/my_app/models/user.ex` -- Ecto schema + changeset
  - `lib/my_app/user_controller.ex` -- CRUD controller actions
  - Prints route entries to add to your router

  ## Options
  - `--no-model` -- Skip model generation
  - `--no-controller` -- Skip controller generation
  - `--json` -- JSON API only (no HTML)
  """

  @doc """
  Runs the scaffold generator to create model, controller, and route entries.

  ## Parameters

    - `args` - Command-line arguments: `[name, field:type, ...options]`

  ## Examples

      ```
      mix gen.scaffold User name:string email:string age:integer
      mix gen.scaffold Post title:string body:text --no-model
      ```
  """
  @impl true
  def run(args) do
    {opts, [name | fields], _} =
      OptionParser.parse(args,
        switches: [model: :boolean, controller: :boolean, json: :boolean],
        aliases: [m: :model, c: :controller, j: :json]
      )

    app = Mix.Project.config()[:app] |> to_string()
    app_module = Macro.camelize(app)
    singular = Macro.underscore(name)
    plural = singular <> "s"
    module_name = Macro.camelize(name)

    unless opts[:model] == false do
      Mix.Tasks.Gen.Model.run([name | fields])
    end

    unless opts[:controller] == false do
      generate_controller(app, app_module, module_name, singular, plural, fields)
    end

    inject_routes(singular, plural, module_name, app_module)
  end

  defp generate_controller(app, app_module, module_name, singular, plural, _fields) do
    controller_content = """
    defmodule #{app_module}.#{module_name}Controller do
      use Hibana.Controller

      def index(conn) do
        #{plural} = [] # TODO: #{app_module}.#{module_name} |> Repo.all()
        json(conn, %{#{plural}: #{plural}})
      end

      def show(conn) do
        id = conn.params["id"]
        # #{singular} = Repo.get!(#{app_module}.#{module_name}, id)
        json(conn, %{#{singular}: %{id: id}})
      end

      def create(conn) do
        # changeset = #{app_module}.#{module_name}.changeset(%#{app_module}.#{module_name}{}, conn.body_params)
        # {:ok, #{singular}} = Repo.insert(changeset)
        conn
        |> put_status(201)
        |> json(%{#{singular}: conn.body_params})
      end

      def update(conn) do
        id = conn.params["id"]
        # #{singular} = Repo.get!(#{app_module}.#{module_name}, id)
        # changeset = #{app_module}.#{module_name}.changeset(#{singular}, conn.body_params)
        # {:ok, updated} = Repo.update(changeset)
        json(conn, %{#{singular}: Map.merge(%{id: id}, conn.body_params)})
      end

      def delete(conn) do
        id = conn.params["id"]
        # #{singular} = Repo.get!(#{app_module}.#{module_name}, id)
        # Repo.delete!(#{singular})
        conn
        |> put_status(204)
        |> text("")
      end
    end
    """

    app_path = File.cwd!()
    controller_path = Path.join([app_path, "lib", app])
    File.mkdir_p!(controller_path)
    file = Path.join(controller_path, "#{singular}_controller.ex")
    File.write!(file, controller_content)
    Mix.shell().info("Generated controller at #{file}")
  end

  defp inject_routes(singular, plural, module_name, app_module) do
    app = Mix.Project.config()[:app] |> to_string()
    router_path = Path.join([File.cwd!(), "lib", app, "router.ex"])

    routes_content = """

    # Routes for #{module_name} resource
    get "/#{plural}", #{app_module}.#{module_name}Controller, :index
    get "/#{plural}/:id", #{app_module}.#{module_name}Controller, :show
    post "/#{plural}", #{app_module}.#{module_name}Controller, :create
    put "/#{plural}/:id", #{app_module}.#{module_name}Controller, :update
    delete "/#{plural}/:id", #{app_module}.#{module_name}Controller, :delete
    """

    if File.exists?(router_path) do
      try do
        # Read router content
        content = File.read!(router_path)

        # Find the end of the module (before the last "end")
        # Insert routes before the final "end"
        if String.contains?(content, "end") do
          # Find last occurrence of "end"
          last_end_index =
            content |> String.split("end") |> Enum.drop(-1) |> Enum.join("end") |> String.length()

          # Insert routes
          new_content =
            String.slice(content, 0, last_end_index) <>
              "  " <>
              routes_content <>
              "\n" <>
              String.slice(content, last_end_index, String.length(content) - last_end_index)

          File.write!(router_path, new_content)
          Mix.shell().info("Added routes to #{router_path}")
        else
          Mix.shell().error("Could not parse router file structure")
          print_routes(singular, plural, module_name, app_module)
        end
      rescue
        e ->
          Mix.shell().error("Could not inject routes: #{inspect(e)}")
          print_routes(singular, plural, module_name, app_module)
      end
    else
      Mix.shell().info("Router not found at #{router_path}")
      print_routes(singular, plural, module_name, app_module)
    end
  end

  defp print_routes(_singular, plural, module_name, app_module) do
    Mix.shell().info("""

    Add these routes to your router:

        get "/#{plural}", #{app_module}.#{module_name}Controller, :index
        get "/#{plural}/:id", #{app_module}.#{module_name}Controller, :show
        post "/#{plural}", #{app_module}.#{module_name}Controller, :create
        put "/#{plural}/:id", #{app_module}.#{module_name}Controller, :update
        delete "/#{plural}/:id", #{app_module}.#{module_name}Controller, :delete
    """)
  end
end
