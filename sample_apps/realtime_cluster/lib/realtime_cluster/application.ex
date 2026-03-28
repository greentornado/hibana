defmodule RealtimeCluster.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      RealtimeCluster.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RealtimeCluster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
