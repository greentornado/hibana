defmodule ResilientServices.Endpoint do
  use Hibana.Endpoint, otp_app: :resilient_services

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug ResilientServices.Router
end
