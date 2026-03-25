defmodule TelegramBot.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.CORS
  plug Hibana.Plugins.HealthCheck, path: "/health"

  post("/webhook/:token", TelegramBot.WebhookController, :webhook)
  get("/setup", TelegramBot.SetupController, :setup)
  get("/status", TelegramBot.SetupController, :status)
  get("/messages", TelegramBot.SetupController, :messages)
end
