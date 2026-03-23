defmodule RestApi.Endpoint do
  use Hibana.Endpoint, otp_app: :rest_api

  plug RestApi.Router
end
