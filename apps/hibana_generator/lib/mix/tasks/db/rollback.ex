defmodule Mix.Tasks.Db.Rollback do
  use Mix.Task

  @shortdoc "Rollback database migrations"

  @moduledoc """
  Rolls back the last database migration.

      mix db.rollback

  ## Options

  - `--repo` - Repo module to use (default: App.Repo)
  - `--step` - Rollback specific number of migrations

  ## Examples

      mix db.rollback
      mix db.rollback --step 2
  """

  @doc """
  Rolls back the last database migration(s).

  ## Parameters

    - `args` - Command-line arguments with optional `--repo`, `--step` flags
  """
  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [repo: :string, step: :integer],
        aliases: [s: :step]
      )

    app_module = Mix.Project.config()[:app] |> to_string() |> Macro.camelize()
    repo = opts[:repo] || "#{app_module}.Repo"

    Mix.shell().info("Rolling back migrations...")

    try do
      repo_module = Module.concat([repo])

      if Code.ensure_loaded?(repo_module) do
        {:ok, _, _} = repo_module.start_link(nil)

        count = rollback_migrations(repo_module, opts)

        Mix.shell().info("Rolled back #{count} migration(s).")
      else
        Mix.shell().error("Repo #{repo} not found.")
        System.halt(1)
      end
    rescue
      _ ->
        Mix.shell().warn("Could not rollback migrations. Please ensure Ecto is configured.")
    end
  end

  defp rollback_migrations(repo_module, opts) do
    step = opts[:step] || 1
    migrator = Module.concat([Ecto, Migrator])

    if Code.ensure_loaded?(migrator) do
      apply(migrator, :run, [repo_module, :down, step, [log: false]])
      |> length()
    else
      Mix.shell().error(
        "Ecto is not available. Add {:ecto_sql, \"~> 3.12\"} to your dependencies."
      )

      0
    end
  end
end
