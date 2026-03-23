defmodule HelloWorld.MixProject do
  use Mix.Project

  def project do
    [
      app: :hello_world,
      version: "0.1.0",
      elixir: "~> 1.16",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {HelloWorld, []}
    ]
  end

  defp deps do
    [
      {:hibana, path: "../../apps/hibana"},
      {:hibana_plugins, path: "../../apps/hibana_plugins"}
    ]
  end
end
