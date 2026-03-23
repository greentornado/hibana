import Config

config :liveview_counter, LiveviewCounter.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4004],
  secret_key_base: "liveview_counter_secret_key_base_for_development_at_least_64_bytes_long"
