import Config

config :hello_world, HelloWorld.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000],
  secret_key_base: "hello_world_secret_key_base_for_development_at_least_64_bytes_long"
