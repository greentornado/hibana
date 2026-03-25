import Config

config :pastebin, Pastebin.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4022],
  secret_key_base: "pastebin_secret_key_base_at_least_64_bytes_long_for_sessions_ok!"
