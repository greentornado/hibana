defmodule Hibana.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls, threshold: 65],
      preferred_envs: [test: :test],
      aliases: aliases()
    ]
  end

  def deps do
    [
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end

  defp aliases do
    [
      test: ["test --cover"],
      "coverage.report": ["coveralls.detail"]
    ]
  end
end
