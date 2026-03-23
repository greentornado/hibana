import Config

config :rest_api, RestApi.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4001],
  secret_key_base: "rest_api_secret_key_base_for_development_at_least_64_bytes_long"
