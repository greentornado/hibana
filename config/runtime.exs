import Config

if config_env() == :prod do
  config :hibana,
    secret_key_base:
      System.get_env("SECRET_KEY_BASE") ||
        raise("""
        environment variable SECRET_KEY_BASE is missing.
        You can generate one by calling: mix secret
        """)

  # JWT authentication
  # config :hibana, :jwt_secret, System.fetch_env!("JWT_SECRET")

  # Database (hibana_ecto)
  # config :hibana_ecto, Hibana.Ecto.Repo,
  #   url: System.fetch_env!("DATABASE_URL"),
  #   pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10")

  # OAuth
  # config :hibana, :oauth,
  #   google_client_id: System.fetch_env!("GOOGLE_CLIENT_ID"),
  #   google_client_secret: System.fetch_env!("GOOGLE_CLIENT_SECRET")
end
