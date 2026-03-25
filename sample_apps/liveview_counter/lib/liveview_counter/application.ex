defmodule LiveviewCounter do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      LiveviewCounter.Endpoint
    ]

    opts = [strategy: :one_for_one, name: LiveviewCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
