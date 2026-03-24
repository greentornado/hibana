defmodule Mix.Tasks.Db.Migrate do
  use Mix.Task

  @shortdoc "Run database migrations"

  @moduledoc """
  Runs pending database migrations.

      mix db.migrate

  ## Options

  - `--repo` - Repo module to use (default: App.Repo)
  - `--step` - Run specific number of migrations
  - `--all` - Run all pending migrations

  ## Examples

      mix db.migrate
      mix db.migrate --step 1
  """

  @doc """
  Runs pending database migrations.

  ## Parameters

    - `args` - Command-line arguments with optional `--repo`, `--step`, `--all` flags
  """
  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [repo: :string, step: :integer, all: :boolean],
        aliases: [s: :step]
      )

    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    repo = opts[:repo] || "#{app_module}.Repo"

    Mix.shell().info("Running migrations...")

    try do
      repo_module = Module.concat([repo])

      if Code.ensure_loaded?(repo_module) do
        {:ok, _, _} = repo_module.start_link(nil)

        migrations = run_migrations(repo_module, opts)

        Mix.shell().info("Migrated #{migrations} migration(s).")
      else
        Mix.shell().error("Repo #{repo} not found.")
        System.halt(1)
      end
    rescue
      _ ->
        Mix.shell().warn("Could not run migrations. Please ensure Ecto is configured.")
        Mix.shell().info("Run 'mix ecto.migrate' if using Ecto directly.")
    end
  end

  defp run_migrations(repo_module, opts) do
    migrator = Module.concat([Ecto, Migrator])

    if Code.ensure_loaded?(migrator) do
      if step = opts[:step] do
        apply(migrator, :run, [repo_module, :up, step, [log: false]])
      else
        apply(migrator, :run, [repo_module, :up, [all: true, log: false]])
      end
      |> length()
    else
      Mix.shell().error(
        "Ecto is not available. Add {:ecto_sql, \"~> 3.12\"} to your dependencies."
      )

      0
    end
  end
end
