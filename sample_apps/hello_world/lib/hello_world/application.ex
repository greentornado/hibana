defmodule HelloWorld do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      HelloWorld.Endpoint
    ]

    opts = [strategy: :one_for_one, name: HelloWorld.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
