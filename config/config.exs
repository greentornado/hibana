import Config

config :hibana,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: "hibana_secret_key_base_for_development",
  start_server: true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :debug

if config_env() == :test do
  config :hibana,
    start_server: false
end
