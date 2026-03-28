import Config

config :routing_benchmark, RoutingBenchmark.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :routing_benchmark,
  secret_key_base: "5dCrRgloX70b2w1cdHeU6ergMmqZVdnVAWZTj0hwEnai+E8c6z12+1KRI3HP7X4Y"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
