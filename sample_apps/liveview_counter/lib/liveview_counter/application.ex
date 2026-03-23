defmodule LiveviewCounter do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      LiveviewCounter.Endpoint
    ]

    opts = [strategy: :one_for_one, name: LiveviewCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
