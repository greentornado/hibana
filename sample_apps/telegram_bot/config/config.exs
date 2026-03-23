import Config

config :telegram_bot, TelegramBot.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4013],
  secret_key_base: "telegram_bot_secret_key_base_for_development_at_least_64_bytes_long"

config :telegram_bot,
  bot_token: "test-token"
