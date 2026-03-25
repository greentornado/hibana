defmodule UrlShortener.Endpoint do
  use Hibana.Endpoint, otp_app: :url_shortener

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Compression
  plug Hibana.Plugins.CORS, origins: ["*"]
  plug Hibana.Plugins.HealthCheck, path: "/health"
  plug Hibana.Plugins.Metrics
  plug UrlShortener.Router
end
