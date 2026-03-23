import Config

config :commerce, Commerce.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4010],
  secret_key_base: "commerce_secret_key_base_for_development_at_least_64_bytes_long_ok"
