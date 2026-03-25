import Config

config :live_poll, LivePoll.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4032],
  secret_key_base: "live_poll_secret_key_base_for_development_at_least_64_bytes_long!!"
