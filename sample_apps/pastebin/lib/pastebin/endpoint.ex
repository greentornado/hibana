defmodule Pastebin.Endpoint do
  use Hibana.Endpoint, otp_app: :pastebin

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Compression
  plug Hibana.Plugins.CORS, origins: ["*"]
  plug Hibana.Plugins.I18n, default_locale: "en", locales: ["en", "vi"]
  plug Hibana.Plugins.HealthCheck, path: "/health"
  plug Hibana.Plugins.Metrics
  plug Hibana.Plugins.SEO,
    sitemap_urls: [%{loc: "http://localhost:4022/", priority: 1.0, changefreq: "daily"}],
    robots: [allow: ["/"], disallow: ["/api"], sitemap: "http://localhost:4022/sitemap.xml"]
  plug Pastebin.Router
end
