defmodule WebhookRelay.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)
  plug(Hibana.Plugins.ColorLogger)
  plug(Hibana.Plugins.ErrorHandler)

  # Receive webhooks
  post("/hooks/:channel", WebhookRelay.HookController, :receive)

  # Subscriptions CRUD
  get("/api/subscriptions", WebhookRelay.SubscriptionController, :index)
  post("/api/subscriptions", WebhookRelay.SubscriptionController, :create)
  delete("/api/subscriptions/:id", WebhookRelay.SubscriptionController, :delete)

  # Event log
  get("/api/events", WebhookRelay.EventController, :index)
  get("/api/events/:id", WebhookRelay.EventController, :show)

  # Channel stats
  get("/api/channels/:name/stats", WebhookRelay.EventController, :channel_stats)
end
