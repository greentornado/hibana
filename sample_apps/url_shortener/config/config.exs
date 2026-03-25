import Config

config :url_shortener, UrlShortener.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4020],
  secret_key_base: "url_shortener_secret_key_base_at_least_64_bytes_long_for_session!"
