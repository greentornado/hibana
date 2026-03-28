defmodule StreamingServer.MixProject do
  use Mix.Project

  def project do
    [
      app: :streaming_server,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {StreamingServer.Application, []}
    ]
  end

  defp deps do
[
      {:hibana, path: "/Users/hai/hb/elixir-web/apps/hibana"},
      {:hibana_plugins, path: "/Users/hai/hb/elixir-web/apps/hibana_plugins"},
      {:plug_cowboy, "~> 2.7"}
    ]
  end
end
