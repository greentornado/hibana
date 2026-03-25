defmodule AuthJwt.Endpoint do
  use Hibana.Endpoint, otp_app: :auth_jwt

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug AuthJwt.Router
end
