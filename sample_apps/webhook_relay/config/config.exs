import Config

config :webhook_relay, WebhookRelay.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4023],
  secret_key_base: "webhook_relay_secret_key_base_for_development_at_least_64_bytes_long"
