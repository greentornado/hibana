import Config

config :bandit_hello, BanditHello.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :bandit_hello,
  secret_key_base: "US638p7G0othV/ARU+czXJfBLOks4RK/9s5H3nuNqlljFoXFCN4isskE6n13ERkX"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
