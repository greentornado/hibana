defmodule Mix.Tasks.Routes do
  use Mix.Task

  @shortdoc "List all routes"

  @moduledoc """
  Lists all routes defined in your application.

      mix routes

  ## Options

  - `--router` - Router module to use (default: App.Router)

  ## Example

      $ mix routes
      Path              Method    Controller#Action
      /users            GET       UserController#index
      /users            POST      UserController#create
      /users/:id        GET       UserController#show
      /users/:id        PUT       UserController#update
      /users/:id        DELETE    UserController#delete
  """

  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [router: :string])

    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    router = opts[:router] || "#{app_module}.Router"

    print_routes(router)
  end

  defp print_routes(router) do
    Mix.shell().info("")
    Mix.shell().info("Path                Method    Controller#Action")
    Mix.shell().info("-" |> String.duplicate(50))

    routes = get_routes(router)

    if Enum.empty?(routes) do
      Mix.shell().info("No routes found. Define routes in your router.")
    else
      Enum.each(routes, fn {path, method, controller, action} ->
        Mix.shell().info("#{pad_path(path)} #{pad_method(method)} #{controller}##{action}")
      end)
    end

    Mix.shell().info("")
  end

  defp pad_path(path) when is_binary(path), do: path |> String.pad_trailing(18)
  defp pad_path(_), do: "" |> String.pad_trailing(18)

  defp pad_method(method) when is_atom(method),
    do: method |> to_string() |> String.pad_trailing(7)

  defp pad_method(method) when is_binary(method), do: method |> String.pad_trailing(7)
  defp pad_method(_), do: "" |> String.pad_trailing(7)

  defp get_routes(router) do
    try do
      router_module = Module.concat([router])

      if Code.ensure_loaded?(router_module) and function_exported?(router_module, :__routes__, 0) do
        router_module.__routes__()
        |> Enum.map(fn
          %{path: path, verb: verb, plug: plug, plug_opts: opts} ->
            controller = Module.concat([plug]) |> to_string() |> String.replace("Controller", "")
            action = if is_atom(opts), do: opts, else: "action"
            {path, verb, controller, action}

          %{path: path, verb: verb, controller: controller, action: action} ->
            {path, verb, controller, action}

          {verb, path, controller, action} ->
            {path, verb, controller, action}

          other ->
            IO.inspect(other, label: "Unknown route format")
            {"", "", "", ""}
        end)
      else
        []
      end
    rescue
      _ in _ ->
        Mix.shell().warn("Router #{router} not found or has no routes")
        []
    end
  end
end
