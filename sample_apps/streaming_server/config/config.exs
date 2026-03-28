import Config

config :streaming_server, StreamingServer.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :streaming_server,
  secret_key_base: "Uepuv4ymWY1bM/PbWuit5XyAxlYbPMxtrC50363afmPfa69C9Ghkw4rZChS4v2gG"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
