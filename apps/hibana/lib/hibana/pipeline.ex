defmodule Hibana.Pipeline do
  @moduledoc """
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
  """

  defmacro __using__(_opts) do
    quote do
      use Hibana.CompiledRouter
      import Hibana.Pipeline
    end
  end

  defmacro pipeline(name, do: block) do
    quote do
      @pipelines {unquote(name), []}
      unquote(block)
    end
  end

  defmacro scope(prefix, opts, do: block) do
    quote do
      @current_scope %{prefix: unquote(prefix), pipeline: unquote(opts[:pipeline])}
      unquote(block)
      @current_scope nil
    end
  end
end
