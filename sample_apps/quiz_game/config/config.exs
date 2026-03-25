import Config

config :quiz_game, QuizGame.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4030],
  secret_key_base: "quiz_game_secret_key_base_for_development_at_least_64_bytes_long_enough"
