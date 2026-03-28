defmodule ResilientServices.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ResilientServices.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ResilientServices.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
