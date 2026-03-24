# `Hibana.Pipeline`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/pipeline.ex#L1)

Middleware pipeline DSL with route groups and per-group plugs.

## Usage

    defmodule MyApp.Router do
      use Hibana.CompiledRouter
      import Hibana.Pipeline

      # Global plugs
      plug Hibana.Plugins.Logger

      # API routes with auth
      pipeline :api do
        plug Hibana.Plugins.JWT, secret: "secret"
        plug Hibana.Plugins.RateLimiter
      end

      # Public routes
      pipeline :public do
        plug Hibana.Plugins.CORS
      end

      scope "/api", pipeline: :api do
        get "/users", UserController, :index
        post "/users", UserController, :create
      end

      scope "/", pipeline: :public do
        get "/health", HealthController, :index
      end
    end

# `pipeline`
*macro* 

# `scope`
*macro* 

---

*Consult [api-reference.md](api-reference.md) for complete listing*
