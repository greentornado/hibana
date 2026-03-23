defmodule Hibana.PluginTest do
  use ExUnit.Case, async: true

  defmodule TestPlugin do
    use Hibana.Plugin

    @impl true
    def init(opts) do
      opts
    end

    @impl true
    def call(conn, opts) do
      Plug.Conn.assign(conn, :test_plugin, Keyword.get(opts, :value, "default"))
    end
  end

  describe "Plugin behaviour" do
    test "init/1 is called with options" do
      assert TestPlugin.init(value: "test") == [value: "test"]
    end

    test "call/2 receives conn and options" do
      conn = %Plug.Conn{state: :unset}
      result = TestPlugin.call(conn, value: "test")
      assert result.assigns[:test_plugin] == "test"
    end
  end

  describe "Plugin.Macro" do
    test "provides __using__ macro" do
      defmodule TestPluginModule do
        use Hibana.Plugin

        def init(opts), do: opts

        def call(conn, _opts), do: conn
      end

      assert function_exported?(TestPluginModule, :init, 1)
      assert function_exported?(TestPluginModule, :call, 2)
    end
  end
end
