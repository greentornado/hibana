import Config

config :realtime_chat, RealtimeChat.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4021],
  secret_key_base: "realtime_chat_secret_key_base_for_development_at_least_64_bytes_long"
