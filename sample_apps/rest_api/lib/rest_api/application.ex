defmodule RestApi do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      RestApi.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RestApi.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
