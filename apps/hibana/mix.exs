defmodule Hibana.Core.MixProject do
  use Mix.Project

  def project do
    [
      app: :hibana,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      deps_path: "../../deps",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    if Mix.env() == :test do
      [extra_applications: [:logger]]
    else
      [
        extra_applications: [:logger],
        mod: {Hibana.Application, []}
      ]
    end
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:cowboy, "~> 2.14"},
      {:plug_cowboy, "~> 2.7"},
      {:mime, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"}
    ]
  end
end
