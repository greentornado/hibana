defmodule RealtimeCluster.Application do
  @moduledoc """
  Application with distributed cluster support.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start cluster with gossip strategy for node discovery
      {Hibana.Cluster, strategy: :gossip, hosts: []},

      # Start endpoint
      RealtimeCluster.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RealtimeCluster.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
