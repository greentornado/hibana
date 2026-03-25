defmodule TypingRace do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: TypingRace.RaceRegistry},
      {DynamicSupervisor, name: TypingRace.RaceSupervisor, strategy: :one_for_one},
      TypingRace.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TypingRace.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
