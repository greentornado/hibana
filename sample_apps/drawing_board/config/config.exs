import Config

config :drawing_board, DrawingBoard.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4031],
  secret_key_base: "drawing_board_secret_key_base_for_development_at_least_64_bytes_long!"
