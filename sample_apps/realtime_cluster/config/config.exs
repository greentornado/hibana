import Config

config :realtime_cluster, RealtimeCluster.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4009]

config :realtime_cluster,
  secret_key_base: "realtime_cluster_secret_key_base_for_development_at_least_64_bytes_long_123456"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
