defmodule Hibana.Generator.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/greentornado/hibana"

  def project do
    base = [
      app: :hibana_generator,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Hibana Generator",
      source_url: @source_url
    ]

    if System.get_env("HEX_PUBLISH") do
      base
    else
      Keyword.merge(base,
        build_path: "../../_build",
        config_path: "../../config/config.exs",
        deps_path: "../../deps",
        lockfile: "../../mix.lock"
      )
    end
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp description do
    "Mix tasks and project generator for the Hibana web framework."
  end

  defp package do
    [
      name: "hibana_generator",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib mix.exs LICENSE)
    ]
  end

  defp docs do
    [
      main: "Mix.Tasks.Gen.App",
      source_ref: "v#{@version}",
      source_url: @source_url
    ]
  end

  defp deps do
    [
      hibana_dep(),
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp hibana_dep do
    if System.get_env("HEX_PUBLISH") do
      {:hibana, "~> #{@version}"}
    else
      {:hibana, in_umbrella: true}
    end
  end
end
