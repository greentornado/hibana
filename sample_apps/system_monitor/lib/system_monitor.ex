defmodule SystemMonitor do
  use Application

  def start(_type, _args) do
    children = [
      SystemMonitor.Collector,
      SystemMonitor.Endpoint
    ]

    opts = [strategy: :one_for_one, name: SystemMonitor.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
