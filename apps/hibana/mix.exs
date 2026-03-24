defmodule Hibana.Core.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/greentornado/hibana"

  def project do
    base = [
      app: :hibana,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Hibana",
      source_url: @source_url,
      homepage_url: @source_url
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
    if Mix.env() == :test do
      [extra_applications: [:logger]]
    else
      [
        extra_applications: [:logger],
        mod: {Hibana.Application, []}
      ]
    end
  end

  defp description do
    "A lightweight Elixir web framework built on Plug and Cowboy. " <>
      "Direct routing like Sinatra, powerful plugins like Phoenix, full OTP power."
  end

  defp package do
    [
      name: "hibana",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "Hibana",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: extras(),
      groups_for_modules: [
        Core: [
          Hibana.Router,
          Hibana.Router.DSL,
          Hibana.CompiledRouter,
          Hibana.Controller,
          Hibana.Endpoint,
          Hibana.Pipeline,
          Hibana.Validator,
          Hibana.TestHelpers
        ],
        "Real-time": [
          Hibana.WebSocket,
          Hibana.WebSocket.CowboyAdapter,
          Hibana.LiveView,
          Hibana.SSE,
          Hibana.Cluster
        ],
        "Background Processing": [
          Hibana.Queue,
          Hibana.Job,
          Hibana.PersistentQueue,
          Hibana.Cron,
          Hibana.CircuitBreaker
        ],
        Infrastructure: [
          Hibana.OTPCache,
          Hibana.GenServer,
          Hibana.Plugin,
          Hibana.Plugin.Registry,
          Hibana.FileStreamer,
          Hibana.ChunkedUpload,
          Hibana.CodeReloader,
          Hibana.EventStore,
          Hibana.Features,
          Hibana.Warmup
        ]
      ]
    ]
  end

  defp extras do
    # Use local README.md when publishing (copied to app dir),
    # fall back to umbrella root for development
    readme =
      cond do
        File.exists?("README.md") -> "README.md"
        File.exists?("../../README.md") -> "../../README.md"
        true -> nil
      end

    changelog =
      cond do
        File.exists?("CHANGELOG.md") -> "CHANGELOG.md"
        File.exists?("../../CHANGELOG.md") -> "../../CHANGELOG.md"
        true -> nil
      end

    [
      readme && {String.to_atom(readme), [title: "Overview"]},
      changelog && {String.to_atom(changelog), [title: "Changelog"]}
    ]
    |> Enum.reject(&is_nil/1)
  end

  defp deps do
    [
      {:plug, "~> 1.16"},
      {:cowboy, "~> 2.14"},
      {:plug_cowboy, "~> 2.7"},
      {:mime, "~> 2.0"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
