defmodule UrlShortener.MixProject do
  use Mix.Project

  def project do
    [
      app: :url_shortener,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {UrlShortener, []}
    ]
  end

  defp deps do
    [
      {:hibana, path: "../../apps/hibana"},
      {:hibana_plugins, path: "../../apps/hibana_plugins"}
    ]
  end
end
