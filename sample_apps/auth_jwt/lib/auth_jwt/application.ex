defmodule AuthJwt do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      AuthJwt.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AuthJwt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
