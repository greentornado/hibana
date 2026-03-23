defmodule Hibana.Features do
  @moduledoc """
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
  """

  @doc "Check if a feature/module is enabled in config"
  def enabled?(module) do
    blocked = Application.get_env(:hibana, :disabled_features, [])

    if module in blocked do
      false
    else
      case Application.get_env(:hibana, :features) do
        # no config = all enabled
        nil -> true
        features when is_list(features) -> module in features
        features when is_map(features) -> Map.get(features, module, false)
      end
    end
  end

  @doc "Filter a list of supervisor children, keeping only enabled ones"
  def filter_children(children) do
    Enum.filter(children, fn
      {module, _opts} -> enabled?(module)
      module when is_atom(module) -> enabled?(module)
    end)
  end

  @doc "Conditionally add a plug only if the module is enabled in config"
  defmacro feature_plug(module, opts \\ []) do
    quote do
      if Hibana.Features.enabled?(unquote(module)) do
        plug unquote(module), unquote(opts)
      end
    end
  end

  @doc "List all enabled features"
  def list_enabled do
    case Application.get_env(:hibana, :features) do
      nil ->
        :all

      features when is_list(features) ->
        features

      features when is_map(features) ->
        features |> Enum.filter(fn {_, v} -> v end) |> Enum.map(fn {k, _} -> k end)
    end
  end

  @doc "List all disabled features"
  def list_disabled do
    case Application.get_env(:hibana, :features) do
      nil ->
        []

      # can't know what's disabled from a list
      features when is_list(features) ->
        []

      features when is_map(features) ->
        features |> Enum.reject(fn {_, v} -> v end) |> Enum.map(fn {k, _} -> k end)
    end
  end

  @doc "Enable a feature at runtime"
  def enable(module) do
    # Remove from blocklist if present
    blocked = Application.get_env(:hibana, :disabled_features, [])
    Application.put_env(:hibana, :disabled_features, List.delete(blocked, module))

    case Application.get_env(:hibana, :features) do
      nil ->
        :ok

      features when is_list(features) ->
        unless module in features do
          Application.put_env(:hibana, :features, [module | features])
        end

      features when is_map(features) ->
        Application.put_env(:hibana, :features, Map.put(features, module, true))
    end

    :ok
  end

  @doc "Disable a feature at runtime"
  def disable(module) do
    case Application.get_env(:hibana, :features) do
      nil ->
        # Use blocklist to track disabled features without losing all-enabled semantics
        blocked = Application.get_env(:hibana, :disabled_features, [])
        Application.put_env(:hibana, :disabled_features, [module | blocked])

      features when is_list(features) ->
        Application.put_env(:hibana, :features, List.delete(features, module))

      features when is_map(features) ->
        Application.put_env(:hibana, :features, Map.put(features, module, false))
    end

    :ok
  end
end
