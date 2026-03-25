defmodule LiveviewCounter.Endpoint do
  use Hibana.Endpoint, otp_app: :liveview_counter

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug LiveviewCounter.Router
end
