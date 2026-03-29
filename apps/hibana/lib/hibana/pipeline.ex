defmodule Hibana.Pipeline do
  @moduledoc """
  Middleware pipeline DSL with named pipelines and scoped route groups.

  Allows grouping plugs into named pipelines and applying them to route
  scopes. This provides a clean way to share middleware across related
  routes without repeating plug declarations.

  ## Features

  - Named pipelines with `pipeline/2` macro - **Fully implemented**
  - Scoped routes with `scope/3` macro - **Partially implemented**
    ⚠️ Scope path prefix and pipeline application are not yet functional.
    Routes defined inside scopes work but don't get the scope prefix or pipeline.
  - Works with `Hibana.CompiledRouter`

  ## Usage

      defmodule MyApp.Router do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        # Global plugs
        plug Hibana.Plugins.Logger

        # Named pipelines work correctly
        pipeline :api do
          plug Hibana.Plugins.JWT, secret: "secret"
          plug Hibana.Plugins.RateLimiter
        end

        # Apply pipeline directly to routes (recommended)
        # Note: scope/3 macro exists but scope features are limited
        get "/api/users", UserController, :index
        post "/api/users", UserController, :create
        plug Hibana.Plugins.JWT, secret: "secret"  # Apply per-route
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
    quote do
      require Logger

      Logger.warning(
        "[Pipeline] scope/3 macro is limited: path prefix and pipeline assignment " <>
          "are not yet fully implemented. Routes inside scopes work but won't get " <>
          "the scope prefix or pipeline applied."
      )

      @current_scope %{prefix: unquote(prefix), pipeline: unquote(opts[:pipeline])}
      unquote(block)
      @current_scope nil
    end
  end
end
