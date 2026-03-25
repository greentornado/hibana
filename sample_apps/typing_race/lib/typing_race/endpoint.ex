defmodule TypingRace.Endpoint do
  use Hibana.Endpoint, otp_app: :typing_race

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug TypingRace.Router
end
