defmodule AuthJwt do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AuthJwt.Endpoint
    ]

    opts = [strategy: :one_for_one, name: AuthJwt.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
