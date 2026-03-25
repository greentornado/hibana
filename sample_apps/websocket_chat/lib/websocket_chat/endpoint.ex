defmodule WebsocketChat.Endpoint do
  use Hibana.Endpoint, otp_app: :websocket_chat

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug WebsocketChat.Router
end
