import Config

config :resilient_services, ResilientServices.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :resilient_services,
  secret_key_base: "bxJbuAMFI18V4sIToCeQdvdVzd4zflrAuFOj/BX+R8H0DVrhAz/J4YXSvQz4pDWV"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
