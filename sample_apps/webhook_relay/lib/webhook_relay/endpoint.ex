defmodule WebhookRelay.Endpoint do
  use Hibana.Endpoint, otp_app: :webhook_relay

  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.CORS)
  plug(Hibana.Plugins.HealthCheck, path: "/health")
  plug(Hibana.Plugins.Metrics)
  plug WebhookRelay.Router
end
