import Config

config :enterprise_suite, EnterpriseSuite.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4011]

config :enterprise_suite,
  secret_key_base: "enterprise_suite_secret_key_base_for_development_at_least_64_bytes_long_123456"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
