import Config

config :auth_jwt, AuthJwt.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4002],
  secret_key_base: "auth_jwt_secret_key_base_for_development_at_least_64_bytes_long",
  jwt_secret: "super_secret_jwt_key_at_least_32_chars_long",
  jwt_algorithm: :hs256,
  jwt_expiration: 3600
