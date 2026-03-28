defmodule StreamingServer.Endpoint do
  use Hibana.Endpoint, otp_app: :streaming_server

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug StreamingServer.Router
end
