defmodule RealtimeChat do
  use Application

  def start(_type, _args) do
    children = [
      RealtimeChat.RoomRegistry,
      RealtimeChat.MessageStore,
      RealtimeChat.PresenceTracker,
      RealtimeChat.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RealtimeChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
