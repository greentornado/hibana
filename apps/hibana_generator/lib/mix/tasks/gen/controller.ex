defmodule Mix.Tasks.Gen.Controller do
  use Mix.Task

  @shortdoc "Generate a new controller"

  @moduledoc """
  Generates a new controller file.

      mix gen.controller User

  This will create:
  - lib/my_app/controllers/user_controller.ex

  ## Options

  - `--path` - Custom path (default: controllers/)
  - `--actions` - Comma-separated actions (default: index,show,new,create,edit,update,delete)

  ## Examples

      mix gen.controller User
      mix gen.controller User --actions index,show
      mix gen.controller Admin/User --path controllers/admin
  """

  @doc """
  Runs the controller generator.

  ## Parameters

    - `args` - Command-line arguments: `[name, ...options]`

  ## Examples

      ```
      mix gen.controller User
      mix gen.controller User --actions index,show
      ```
  """
  @impl true
  def run(args) do
    {opts, [name | _], _} =
      OptionParser.parse(args,
        switches: [path: :string, actions: :string],
        aliases: [p: :path, a: :actions]
      )

    generate_controller(name, opts)
  end

  defp generate_controller(name, opts) do
    controller_module = Macro.camelize(name)
    controller_file = Macro.underscore(name)
    actions = opts[:actions] || "index,show,new,create,edit,update,delete"
    action_list = String.split(actions, ",")
    path = opts[:path] || "controllers"

    app_path = File.cwd!()
    controller_path = Path.join([app_path, "lib", to_string(Mix.Project.config()[:app]), path])

    File.mkdir_p!(controller_path)

    controller_content = """
    defmodule #{controller_module}Controller do
      use Hibana.Controller

      #{generate_actions(action_list, controller_module)}
    end
    """

    file_path = Path.join(controller_path, "#{controller_file}_controller.ex")
    File.write!(file_path, controller_content)

    Mix.shell().info("Generated controller at #{file_path}")
  end

  defp generate_actions(actions, _module) do
    Enum.map(actions, &generate_action/1) |> Enum.join("\n  ")
  end

  defp generate_action("index") do
    """
    def index(conn, _params) do
      json(conn, %{data: []})
    end
    """
  end

  defp generate_action("show") do
    """
    def show(conn, _params) do
      id = conn.params["id"]
      json(conn, %{data: %{id: id}})
    end
    """
  end

  defp generate_action("new") do
    """
    def new(conn, _params) do
      json(conn, %{data: %{}})
    end
    """
  end

  defp generate_action("create") do
    """
    def create(conn, _params) do
      body = conn.body_params
      json(conn, %{data: body, message: "Created"})
    end
    """
  end

  defp generate_action("edit") do
    """
    def edit(conn, _params) do
      id = conn.params["id"]
      json(conn, %{data: %{id: id}})
    end
    """
  end

  defp generate_action("update") do
    """
    def update(conn, _params) do
      id = conn.params["id"]
      body = conn.body_params
      json(conn, %{data: %{id: id, body: body}, message: "Updated"})
    end
    """
  end

  defp generate_action("delete") do
    """
    def delete(conn, _params) do
      id = conn.params["id"]
      json(conn, %{message: "Deleted \#{id}"})
    end
    """
  end

  defp generate_action("edit") do
    """
    def edit(conn, %{id: id}) do
      json(conn, %{data: %{id: id}})
    end
    """
  end

  defp generate_action("update") do
    """
    def update(conn, %{id: id, body: body}) do
      json(conn, %{data: Map.put(body, :id, id), message: "Updated"})
    end
    """
  end

  defp generate_action("delete") do
    """
    def delete(conn, %{id: id}) do
      json(conn, %{message: "Deleted", id: id})
    end
    """
  end

  defp generate_action(other) do
    """
    def #{other}(conn, _params) do
      json(conn, %{data: %{}})
    end
    """
  end
end
