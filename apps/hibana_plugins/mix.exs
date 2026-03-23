defmodule Hibana.Plugins.MixProject do
  use Mix.Project

  def project do
    [
      app: :hibana_plugins,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hibana, in_umbrella: true},
      {:plug, "~> 1.16"},
      {:jose, "~> 1.11"},
      {:hackney, "~> 3.2"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:cowboy, "~> 2.14"},
      {:plug_cowboy, "~> 2.7"},
      {:mime, "~> 2.0"}
    ]
  end
end
