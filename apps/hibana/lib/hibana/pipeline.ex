defmodule Hibana.Pipeline do
  @moduledoc """
  Middleware pipeline DSL with named pipelines and scoped route groups.

  Allows grouping plugs into named pipelines and applying them to route
  scopes. This provides a clean way to share middleware across related
  routes without repeating plug declarations.

  ## Features

  - Named pipelines with `pipeline/2` macro
  - Scoped routes with `scope/3` macro
  - Per-scope pipeline assignment
  - Works with `Hibana.CompiledRouter`

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

  ## Macros

  | Macro | Description |
  |-------|-------------|
  | `pipeline/2` | Define a named group of plugs |
  | `scope/3` | Group routes under a path prefix with a pipeline |
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
