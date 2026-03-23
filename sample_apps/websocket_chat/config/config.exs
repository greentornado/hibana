import Config

config :websocket_chat, WebsocketChat.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4003],
  secret_key_base: "websocket_chat_secret_key_base_for_development_at_least_64_bytes_long"
