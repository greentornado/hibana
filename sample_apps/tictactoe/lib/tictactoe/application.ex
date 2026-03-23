defmodule TicTacToe do
  use Application

  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: TicTacToe.GameRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: TicTacToe.GameSupervisor},
      TicTacToe.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TicTacToe.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
