defmodule Hibana.Ecto.MixProject do
  use Mix.Project

  def project do
    [
      app: :hibana_ecto,
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
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:hibana, in_umbrella: true},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:myxql, "~> 0.7"},
      {:postgrex, "~> 0.17"},
      {:mongodb_driver, "~> 1.6"},
      {:jason, "~> 1.4"}
    ]
  end
end
