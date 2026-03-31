defmodule Hibana.Pipeline do
  @moduledoc """
  Middleware pipeline DSL with named pipelines and scoped route groups.

  Allows grouping plugs into named pipelines and applying them to route
  scopes. This provides a clean way to share middleware across related
  routes without repeating plug declarations.

  ## Features

  - Named pipelines with `pipeline/2` macro - **Fully implemented**
  - Scoped routes with `scope/3` macro - **Fully implemented**
    Routes defined inside scopes automatically get the path prefix and
    pipeline plugs applied.
  - Works with `Hibana.CompiledRouter`

  ## Usage

      defmodule MyApp.Router do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        # Global plugs
        plug Hibana.Plugins.Logger

        # Named pipelines
        pipeline :api do
          plug Hibana.Plugins.JWT, secret: "secret"
          plug Hibana.Plugins.RateLimiter
        end

        pipeline :admin do
          plug Hibana.Plugins.Auth, username: "admin", password: "secret"
        end

        # Scoped routes with path prefix and pipeline
        scope "/api", pipe_through: [:api] do
          get "/users", UserController, :index
          post "/users", UserController, :create
        end

        # Nested scopes
        scope "/api", pipe_through: [:api] do
          scope "/admin", pipe_through: [:admin] do
            get "/stats", AdminController, :stats
          end
        end

        # Regular routes (outside scope)
        get "/", PageController, :index
      end
  """

  defmacro __using__(_opts) do
    quote do
      use Hibana.CompiledRouter
      import Hibana.Pipeline
    end
  end

  defmacro pipeline(name, do: block) do
    # Accumulate plugs within the pipeline block
    quote do
      Module.register_attribute(__MODULE__, :current_pipeline_plugs, accumulate: true)
      @current_pipeline_name unquote(name)
      unquote(block)
      @pipelines {unquote(name), @current_pipeline_plugs}
      Module.delete_attribute(__MODULE__, :current_pipeline_name)
      Module.delete_attribute(__MODULE__, :current_pipeline_plugs)
    end
  end

  defmacro plug(plug_module, opts \\ []) do
    quote do
      if Module.get_attribute(__MODULE__, :current_pipeline_name) do
        # Inside a pipeline block - accumulate
        @current_pipeline_plugs {unquote(plug_module), unquote(opts)}
      else
        # Standalone plug at module level - use CompiledRouter's plug
        @plugs {unquote(plug_module), unquote(opts)}
      end
    end
  end

  defmacro scope(prefix, opts, do: block) do
    pipelines = opts[:pipe_through] || []

    quote do
      # Save current scope state
      current_scope = Module.get_attribute(__MODULE__, :current_scope)

      # Calculate new scope prefix by combining with parent scope
      new_prefix =
        if current_scope do
          current_scope.prefix <> unquote(prefix)
        else
          unquote(prefix)
        end

      # Calculate pipelines by combining with parent scope
      parent_pipelines = if current_scope, do: current_scope.pipelines, else: []
      new_pipelines = parent_pipelines ++ unquote(pipelines)

      # Set new scope
      @current_scope %{prefix: new_prefix, pipelines: new_pipelines}

      # Execute the block
      unquote(block)

      # Restore previous scope
      @current_scope current_scope
    end
  end

  @doc """
  Macro called by route macros (get, post, etc.) to apply scope configuration.

  This is used internally by Hibana.CompiledRouter to ensure routes defined
  inside scopes get the correct path prefix and pipeline plugs.
  """
  defmacro __route__(method, path, target, opts \\ []) do
    quote do
      # Get current scope configuration
      scope = Module.get_attribute(__MODULE__, :current_scope)

      # Apply scope prefix if present
      full_path =
        if scope && scope.prefix do
          scope.prefix <> unquote(path)
        else
          unquote(path)
        end

      # Store pipeline plugs to be applied
      if scope && scope.pipelines != [] do
        @route_pipelines {unquote(method), full_path, scope.pipelines}
      end

      # Register the route with full path
      @routes {unquote(method), full_path, unquote(target), unquote(opts)}
    end
  end
end
