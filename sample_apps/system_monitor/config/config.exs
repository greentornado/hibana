import Config

config :system_monitor, SystemMonitor.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4024],
  secret_key_base: "system_monitor_secret_key_base_for_development_at_least_64_bytes_long"
