defmodule StreamingServer.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      StreamingServer.Endpoint
    ]

    opts = [strategy: :one_for_one, name: StreamingServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
