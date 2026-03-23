defmodule Hibana.Plugin.RegistryTest do
  use ExUnit.Case, async: true

  defmodule TestPlugin do
    @behaviour Hibana.Plugin

    @impl true
    def init(opts) do
      Keyword.merge([default: true], opts)
    end

    @impl true
    def call(conn, opts) do
      %{conn | assigns: Map.put(conn.assigns, :plugin_test, opts[:default])}
    end
  end

  defmodule AnotherPlugin do
    @behaviour Hibana.Plugin

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _opts), do: conn
  end

  setup do
    name = :"test_registry_#{System.unique_integer([:positive])}"
    {:ok, pid} = Hibana.Plugin.Registry.start_link(name: name)
    %{registry: pid, name: name}
  end

  describe "start_link/1" do
    test "starts with default name" do
      name = :"test_start_#{System.unique_integer([:positive])}"
      {:ok, pid} = Hibana.Plugin.Registry.start_link(name: name)
      assert is_pid(pid)
    end
  end

  describe "register/4" do
    test "registers a plugin with options", %{name: name} do
      :ok = Hibana.Plugin.Registry.register(name, :my_plugin, TestPlugin, custom: true)
      plugin = Hibana.Plugin.Registry.get_plugin(name, :my_plugin)

      assert plugin != nil
      assert plugin.module == TestPlugin
      assert plugin.opts[:default] == true
      assert plugin.opts[:custom] == true
    end

    test "overwrites existing plugin registration", %{name: name} do
      :ok = Hibana.Plugin.Registry.register(name, :dup_plugin, TestPlugin, [])
      :ok = Hibana.Plugin.Registry.register(name, :dup_plugin, AnotherPlugin, [])

      plugin = Hibana.Plugin.Registry.get_plugin(name, :dup_plugin)
      assert plugin.module == AnotherPlugin
    end
  end

  describe "unregister/2" do
    test "removes a registered plugin", %{name: name} do
      :ok = Hibana.Plugin.Registry.register(name, :to_remove, TestPlugin, [])
      :ok = Hibana.Plugin.Registry.unregister(name, :to_remove)

      plugin = Hibana.Plugin.Registry.get_plugin(name, :to_remove)
      assert plugin == nil
    end
  end

  describe "list_plugins/1" do
    test "returns empty list when no plugins registered", %{name: name} do
      plugins = Hibana.Plugin.Registry.list_plugins(name)
      assert plugins == []
    end

    test "returns list of registered plugin names", %{name: name} do
      Hibana.Plugin.Registry.register(name, :plugin_a, TestPlugin, [])
      Hibana.Plugin.Registry.register(name, :plugin_b, AnotherPlugin, [])

      plugins = Hibana.Plugin.Registry.list_plugins(name)
      assert :plugin_a in plugins
      assert :plugin_b in plugins
      assert length(plugins) == 2
    end
  end

  describe "get_plugin/2" do
    test "returns nil for non-existent plugin", %{name: name} do
      plugin = Hibana.Plugin.Registry.get_plugin(name, :nonexistent)
      assert plugin == nil
    end

    test "returns plugin details for registered plugin", %{name: name} do
      Hibana.Plugin.Registry.register(name, :test_get, TestPlugin, key: "value")

      plugin = Hibana.Plugin.Registry.get_plugin(name, :test_get)
      assert plugin.module == TestPlugin
      assert plugin.opts[:key] == "value"
    end
  end
end
