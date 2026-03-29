import Config

config :resilient_services, ResilientServices.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4010]

config :resilient_services,
  secret_key_base: "resilient_services_secret_key_base_for_development_at_least_64_bytes_long_123456"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
