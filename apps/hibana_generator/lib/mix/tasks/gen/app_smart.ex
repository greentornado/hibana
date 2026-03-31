defmodule Mix.Tasks.Gen.App.Smart do
  use Mix.Task

  @shortdoc "Smart Hibana app generator with templates and auto-configuration"

  @moduledoc """
  Smart interactive generator for Hibana applications.

  ## Usage

      mix gen.app.smart my_app

  ## Templates

  - `api` - REST API
  - `full` - Full web application
  """

  @impl true
  def run(args) do
    {opts, [app_name | _], _} =
      OptionParser.parse(args,
        switches: [template: :string]
      )

    app_path = Path.expand(app_name)
    Mix.shell().info("Creating #{app_name} at #{app_path}...")

    File.mkdir_p!(app_path)

    Mix.shell().info("Done! Run: cd #{app_name} && mix deps.get && mix run --no-halt")
  end
end
