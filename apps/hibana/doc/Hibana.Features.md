# `Hibana.Features`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/features.ex#L1)

Feature toggle system for enabling/disabling plugins and modules via config.

## Usage

In `config/config.exs`, list which features are enabled:

    config :hibana, :features, [
      Hibana.Plugins.Logger,
      Hibana.Plugins.BodyParser,
      Hibana.Plugins.CORS,
      Hibana.Plugins.JWT,
      # Hibana.Plugins.RateLimiter,    # <-- commented = disabled
      # Hibana.Plugins.GraphQL,        # <-- commented = disabled
    ]

Or use a map for explicit on/off:

    config :hibana, :features, %{
      Hibana.Plugins.Logger => true,
      Hibana.Plugins.BodyParser => true,
      Hibana.Plugins.CORS => true,
      Hibana.Plugins.RateLimiter => false,   # disabled
      Hibana.Plugins.GraphQL => false,        # disabled
    }

## In your Router

    defmodule MyApp.Router do
      use Hibana.CompiledRouter
      import Hibana.Features

      # Only loads if enabled in config
      feature_plug Hibana.Plugins.Logger
      feature_plug Hibana.Plugins.BodyParser
      feature_plug Hibana.Plugins.CORS, origins: ["*"]
      feature_plug Hibana.Plugins.RateLimiter, max_requests: 100
      feature_plug Hibana.Plugins.JWT, secret: "secret"

      get "/", PageController, :index
    end

## Runtime Check

    if Hibana.Features.enabled?(Hibana.Plugins.RateLimiter) do
      # rate limiter logic
    end

## Supervisor Children

    # Only start enabled services
    children = Hibana.Features.filter_children([
      {Hibana.Cluster, strategy: :epmd},
      {Hibana.PersistentQueue, name: :jobs},
      {Hibana.Plugins.Metrics, []},
    ])

# `disable`

Disable a feature at runtime

# `enable`

Enable a feature at runtime

# `enabled?`

Check if a feature/module is enabled in config

# `feature_plug`
*macro* 

Conditionally add a plug only if the module is enabled in config

# `filter_children`

Filter a list of supervisor children, keeping only enabled ones

# `list_disabled`

List all disabled features

# `list_enabled`

List all enabled features

---

*Consult [api-reference.md](api-reference.md) for complete listing*
