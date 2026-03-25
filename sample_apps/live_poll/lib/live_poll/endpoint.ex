defmodule LivePoll.Endpoint do
  use Hibana.Endpoint, otp_app: :live_poll

  plug LivePoll.Router
end
