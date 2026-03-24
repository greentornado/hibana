defmodule Mix.Tasks.Db.Create do
  use Mix.Task

  @shortdoc "Create the database"

  @moduledoc """
  Creates the database for your application.

      mix db.create

  ## Options

  - `--repo` - Repo module to use (default: App.Repo)

  ## Examples

      mix db.create
      mix db.create --repo MyApp.Repo
  """

  @doc """
  Creates the database for the configured Ecto repo.

  ## Parameters

    - `args` - Command-line arguments with optional `--repo` flag
  """
  @impl true
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: [repo: :string])

    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    repo = opts[:repo] || "#{app_module}.Repo"

    Mix.shell().info("Creating database...")

    try do
      repo_module = Module.concat([repo])

      if Code.ensure_loaded?(repo_module) do
        apply(repo_module, :start_link, [])

        case repo_module.__adapter__().storage_up([]) do
          :ok ->
            Mix.shell().info("Database created successfully!")

          {:error, :already_up} ->
            Mix.shell().info("Database already exists.")

          {:error, reason} ->
            Mix.shell().error("Failed to create database: #{inspect(reason)}")
            System.halt(1)
        end
      else
        Mix.shell().error("Repo #{repo} not found. Make sure it's compiled.")
        System.halt(1)
      end
    rescue
      e ->
        Mix.shell().error("Database creation failed: #{Exception.message(e)}")
        Mix.shell().warn("Could not auto-detect adapter. Please ensure your repo is configured.")
        Mix.shell().info("Run 'mix ecto.create' if using Ecto directly.")
    end
  end
end
