defmodule Mix.Tasks.Server do
  use Mix.Task

  @shortdoc "Start the Hibana server"

  @moduledoc """
  Starts the Hibana application server.

      mix server

  ## Options

  - `--host` - Host to bind to (default: 0.0.0.0)
  - `--port` - Port to listen on (default: 4000)
  - `--prod` - Start in production mode
  - `--no-compile` - Skip compilation

  ## Examples

      mix server
      mix server --port 3000
      mix server --host localhost --port 8080
  """

  @doc """
  Starts the Hibana application server.

  ## Parameters

    - `args` - Command-line arguments with optional `--host`, `--port`, `--prod`, `--no-compile` flags
  """
  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [host: :string, port: :integer, prod: :boolean, no_compile: :boolean],
        aliases: [p: :port, h: :host]
      )

    unless opts[:no_compile] do
      Mix.Task.run("compile", [])
      Mix.Task.run("app.start", [])
    end

    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    host = opts[:host] || Application.get_env(app_module, :host, {0, 0, 0, 0})
    port = opts[:port] || Application.get_env(app_module, :port, 4000)

    Mix.shell().info("Starting #{app_module} on http://#{format_host(host)}:#{port}")

    Application.put_env(app_module, :http, ip: host, port: port)

    case Application.ensure_all_started(app_module) do
      {:ok, _} ->
        :timer.sleep(:infinity)

      {:error, reason} ->
        Mix.shell().error("Failed to start #{app_module}: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp format_host({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"
  defp format_host(host), do: host
end
