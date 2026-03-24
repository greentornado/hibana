defmodule Hibana.Ecto.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/greentornado/hibana"

  def project do
    [
      app: :hibana_ecto,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      lockfile: "../../mix.lock",
      deps_path: "../../deps",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Hibana Ecto",
      source_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Ecto database integration for the Hibana web framework (MySQL, PostgreSQL, MongoDB)."
  end

  defp package do
    [
      name: "hibana_ecto",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url
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
      {:jason, "~> 1.4"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
