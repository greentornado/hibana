import Config

config :auction, Auction.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4033],
  secret_key_base: "auction_secret_key_base_for_development_at_least_64_bytes_long_enough"
