import Config

config :tictactoe, TicTacToe.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4012],
  secret_key_base: "tictactoe_secret_key_base_for_development_at_least_64_bytes_long"
