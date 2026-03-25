defmodule HelloWorld.Endpoint do
  use Hibana.Endpoint, otp_app: :hello_world

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.ColorLogger
  plug HelloWorld.Router
end
