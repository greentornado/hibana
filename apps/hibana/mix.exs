defmodule Hibana.Core.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/greentornado/hibana"

  def project do
    [
      app: :hibana,
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
      name: "Hibana",
      source_url: @source_url,
      homepage_url: @source_url
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
      extras: [
        "../../README.md": [title: "Overview"],
        "../../CHANGELOG.md": [title: "Changelog"]
      ],
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
