defmodule BanditHello.MixProject do
  use Mix.Project

  def project do
    [
      app: :bandit_hello,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {BanditHello.Application, []}
    ]
  end

  defp deps do
[
      {:hibana, path: "/Users/hai/hb/elixir-web/apps/hibana"},
      {:hibana_plugins, path: "/Users/hai/hb/elixir-web/apps/hibana_plugins"},
      {:bandit, "~> 1.0"}
    ]
  end
end
