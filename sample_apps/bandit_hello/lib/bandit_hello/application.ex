defmodule BanditHello.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BanditHello.Endpoint
    ]

    opts = [strategy: :one_for_one, name: BanditHello.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
