defmodule HelloWorld.Endpoint do
  use Hibana.Endpoint, otp_app: :hello_world

  plug HelloWorld.Router
end
