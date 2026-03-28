defmodule BanditHello.Endpoint do
  use Hibana.BanditEndpoint, otp_app: :bandit_hello

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug BanditHello.Router
end
