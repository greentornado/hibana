defmodule TelegramBot.Endpoint do
  use Hibana.Endpoint, otp_app: :telegram_bot

  plug TelegramBot.Router
end
