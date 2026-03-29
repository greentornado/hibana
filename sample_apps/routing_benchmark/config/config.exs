import Config

config :routing_benchmark, RoutingBenchmark.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4007]

config :routing_benchmark,
  secret_key_base: "routing_benchmark_secret_key_base_for_development_at_least_64_bytes_long_123456"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
