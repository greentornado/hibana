defmodule Hibana.Generator.MixProject do
  use Mix.Project

  def project do
    [
      app: :hibana_generator,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      deps_path: "../../deps",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [gen: "run lib/mix/tasks/gen/app.ex"]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hibana, in_umbrella: true}
    ]
  end
end
