import Config

config :typing_race, TypingRace.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4034],
  secret_key_base: "typing_race_secret_key_base_for_development_at_least_64_bytes_long_enough"
