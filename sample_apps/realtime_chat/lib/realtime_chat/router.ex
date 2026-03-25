defmodule RealtimeChat.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.ErrorHandler

  # HTML page
  get("/", RealtimeChat.PageController, :index)

  # WebSocket endpoint
  get("/ws/chat", RealtimeChat.ChatSocket, :upgrade)

  # REST API
  get("/api/rooms", RealtimeChat.RoomController, :index)
  post("/api/rooms", RealtimeChat.RoomController, :create)
  get("/api/rooms/:id/messages", RealtimeChat.RoomController, :messages)
end
