defmodule WebsocketChat do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Registry, keys: :unique, name: WebsocketChat.RoomRegistry},
      WebsocketChat.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WebsocketChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
