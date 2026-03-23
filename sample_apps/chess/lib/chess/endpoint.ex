defmodule Chess.Endpoint do
  use Hibana.Endpoint, otp_app: :chess

  plug Chess.Router
end
