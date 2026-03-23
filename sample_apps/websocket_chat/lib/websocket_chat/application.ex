defmodule WebsocketChat do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      {Registry, keys: :unique, name: WebsocketChat.RoomRegistry},
      WebsocketChat.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WebsocketChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
