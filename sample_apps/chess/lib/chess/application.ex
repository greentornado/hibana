defmodule Chess do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: Chess.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Chess.GameSupervisor},
      Chess.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Chess.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
