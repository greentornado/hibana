import Config

config :realtime_cluster, RealtimeCluster.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :realtime_cluster,
  secret_key_base: "cw5I7ebuuq2ITAoOjOcqFaA7hm1Gr1U4E1Zm6Gb/wxM+8jvhGjripf8AdrTLvCp9"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
