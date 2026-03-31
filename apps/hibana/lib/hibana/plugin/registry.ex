defmodule Hibana.Plugin.Registry do
  @moduledoc """
  Registry for managing plugins at runtime.

  ## Features

  - Register/unregister plugins dynamically
  - List all registered plugins
  - Get plugin configuration
  - Thread-safe via GenServer

  ## Usage

      # Start the registry
      {:ok, pid} = Hibana.Plugin.Registry.start_link(name: :my_plugins)

      # Register a plugin
      Hibana.Plugin.Registry.register(
        :my_plugins,
        :auth,
        MyApp.AuthPlugin,
        opts: [secret: "secret"]
      )

      # List all plugins
      Hibana.Plugin.Registry.list_plugins(:my_plugins)

      # Get a specific plugin
      Hibana.Plugin.Registry.get_plugin(:my_plugins, :auth)

      # Unregister a plugin
      Hibana.Plugin.Registry.unregister(:my_plugins, :auth)

  ## Supervision Integration

      children = [
        {Hibana.Plugin.Registry, name: :plugin_registry}
      ]
  """

  use GenServer

  @doc "Start the plugin registry process."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  def init(_opts) do
    {:ok, %{plugins: %{}}}
  end

  @doc """
  Register a plugin module under the given name with options.

  ## Returns

    - `:ok` on success
    - `{:error, {:init_failed, exception}}` if plugin initialization raises an exception
    - `{:error, {:init_crashed, kind, reason}}` if plugin initialization crashes
  """
  def register(server \\ __MODULE__, name, plugin_module, opts \\ []) do
    GenServer.call(server, {:register, name, plugin_module, opts})
  end

  @doc "Unregister a plugin by name."
  def unregister(server \\ __MODULE__, name) do
    GenServer.call(server, {:unregister, name})
  end

  @doc "List the names of all registered plugins."
  def list_plugins(server \\ __MODULE__) do
    GenServer.call(server, :list_plugins)
  end

  @doc "Get a registered plugin's module and options by name."
  def get_plugin(server \\ __MODULE__, name) do
    GenServer.call(server, {:get_plugin, name})
  end

  def handle_call({:register, name, plugin_module, opts}, _from, state) do
    try do
      initialized_opts = plugin_module.init(opts)
      new_state = put_in(state.plugins[name], %{module: plugin_module, opts: initialized_opts})
      {:reply, :ok, new_state}
    rescue
      e ->
        require Logger

        Logger.error(
          "[Plugin.Registry] Failed to initialize plugin #{inspect(name)} (#{inspect(plugin_module)}): #{inspect(e)}"
        )

        {:reply, {:error, {:init_failed, e}}, state}
    catch
      kind, reason ->
        require Logger

        Logger.error(
          "[Plugin.Registry] Plugin #{inspect(name)} (#{inspect(plugin_module)}) crashed during init: #{kind} #{inspect(reason)}"
        )

        {:reply, {:error, {:init_crashed, kind, reason}}, state}
    end
  end

  def handle_call({:unregister, name}, _from, state) do
    new_state = update_in(state.plugins, &Map.delete(&1, name))
    {:reply, :ok, new_state}
  end

  def handle_call(:list_plugins, _from, state) do
    {:reply, Map.keys(state.plugins), state}
  end

  def handle_call({:get_plugin, name}, _from, state) do
    {:reply, Map.get(state.plugins, name), state}
  end
end
