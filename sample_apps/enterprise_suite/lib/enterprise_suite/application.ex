defmodule EnterpriseSuite.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EnterpriseSuite.Endpoint
    ]

    opts = [strategy: :one_for_one, name: EnterpriseSuite.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
