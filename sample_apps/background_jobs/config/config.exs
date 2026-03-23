import Config

config :background_jobs, BackgroundJobs.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4005],
  secret_key_base: "background_jobs_secret_key_base_for_development_at_least_64_bytes_long"
