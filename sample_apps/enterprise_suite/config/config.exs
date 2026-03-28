import Config

config :enterprise_suite, EnterpriseSuite.Endpoint,
  http: [ip: {0, 0, 0, 0}, port: 4000]

config :enterprise_suite,
  secret_key_base: "4tuRLADKtnmS4SbEoWhCnAyiegW+QvbBgb16dbZqWq3cgpl/EcuMnA13ikYDljL1"

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info
