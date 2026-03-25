defmodule Auction.Endpoint do
  use Hibana.Endpoint, otp_app: :auction

  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.Logger)
  plug Auction.Router
end
