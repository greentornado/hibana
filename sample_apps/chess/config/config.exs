import Config

config :chess, Chess.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4011],
  secret_key_base: "chess_secret_key_base_for_development_at_least_64_bytes_long_here"
