defmodule SystemMonitor.Endpoint do
  use Hibana.Endpoint, otp_app: :system_monitor

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.CORS, origins: ["*"]
  plug Hibana.Plugins.HealthCheck, path: "/health"
  plug Hibana.Plugins.Metrics
  plug Hibana.Plugins.Compression
  plug SystemMonitor.Router
end
