defmodule Commerce.Endpoint do
  use Hibana.Endpoint, otp_app: :commerce

  plug Commerce.Router
end
