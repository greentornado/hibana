defmodule Hibana.Plugins.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/greentornado/hibana"

  def project do
    base = [
      app: :hibana_plugins,
      version: @version,
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      docs: docs(),
      name: "Hibana Plugins",
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
    "35 built-in plugins for the Hibana web framework: " <>
      "JWT, OAuth, CORS, rate limiting, GraphQL, admin dashboard, i18n, and more."
  end

  defp package do
    [
      name: "hibana_plugins",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs LICENSE)
    ]
  end

  defp docs do
    [
      main: "Hibana.Plugins.JWT",
      source_ref: "v#{@version}",
      source_url: @source_url,
      groups_for_modules: [
        "Security & Auth": [
          Hibana.Plugins.JWT,
          Hibana.Plugins.OAuth,
          Hibana.Plugins.Auth,
          Hibana.Plugins.APIKey,
          Hibana.Plugins.TOTP,
          Hibana.Plugins.RequestSigning,
          Hibana.Plugins.CORS,
          Hibana.Plugins.ScopedCORS,
          Hibana.Plugins.RateLimiter,
          Hibana.Plugins.DistributedRateLimiter
        ],
        "Request Processing": [
          Hibana.Plugins.BodyParser,
          Hibana.Plugins.Session,
          Hibana.Plugins.RequestId,
          Hibana.Plugins.Compression,
          Hibana.Plugins.ContentNegotiation,
          Hibana.Plugins.APIVersioning,
          Hibana.Plugins.I18n
        ],
        "Monitoring & Ops": [
          Hibana.Plugins.Logger,
          Hibana.Plugins.ColorLogger,
          Hibana.Plugins.Metrics,
          Hibana.Plugins.HealthCheck,
          Hibana.Plugins.GracefulShutdown,
          Hibana.Plugins.TelemetryDashboard,
          Hibana.Plugins.LiveDashboard
        ],
        "Data & Content": [
          Hibana.Plugins.Cache,
          Hibana.Plugins.OTPCache,
          Hibana.Plugins.Static,
          Hibana.Plugins.Upload,
          Hibana.Plugins.GraphQL,
          Hibana.Plugins.Search,
          Hibana.Plugins.SEO
        ],
        "Development & Admin": [
          Hibana.Plugins.ErrorHandler,
          Hibana.Plugins.DevErrorPage,
          Hibana.Plugins.Admin,
          Hibana.Plugins.LiveViewChannel
        ]
      ]
    ]
  end

  defp deps do
    [
      hibana_dep(),
      {:plug, "~> 1.16"},
      {:jose, "~> 1.11"},
      {:hackney, "~> 3.2"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.3"},
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
