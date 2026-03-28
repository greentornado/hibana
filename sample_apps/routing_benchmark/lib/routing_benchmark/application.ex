defmodule RoutingBenchmark.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RoutingBenchmark.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RoutingBenchmark.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
