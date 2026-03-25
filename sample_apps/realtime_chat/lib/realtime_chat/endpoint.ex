defmodule RealtimeChat.Endpoint do
  use Hibana.Endpoint, otp_app: :realtime_chat

  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.CORS)
  plug(Hibana.Plugins.Session, secret: "realtime_chat_session_secret_key_base_64_bytes_long_minimum!!")
  plug(Hibana.Plugins.Static, at: "/", from: "priv/static")
  plug(Hibana.Plugins.HealthCheck)
  plug(RealtimeChat.Router)
end
