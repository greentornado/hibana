defmodule Hibana.PluginMacroTest do
  @moduledoc """
  Tests to force Hibana.Plugin macro execution for coverage.
  """
  use ExUnit.Case, async: true

  # Define test modules at compile time
  defmodule TestPlugin1 do
    use Hibana.Plugin

    def call(conn, _opts) do
      Plug.Conn.put_private(conn, :plugin_called, true)
    end
  end

  defmodule TestPlugin2 do
    use Hibana.Plugin

    def init(opts) do
      Keyword.put(opts, :custom_init, true)
    end

    def call(conn, opts) do
      Plug.Conn.put_private(conn, :opts, opts)
    end
  end

  defmodule TestPlugin3 do
    use Hibana.Plugin
    # Don't override call - uses default
  end

  describe "Plugin macro execution" do
    test "__using__ generates init/1 function" do
      # Test the default init function
      assert TestPlugin1.init(test: true) == [test: true]
    end

    test "__using__ generates before_send/2 function" do
      conn = %Plug.Conn{}
      assert TestPlugin1.before_send(conn, []) == conn
    end

    test "__using__ generates start_link/1 function" do
      {:ok, pid} = TestPlugin1.start_link(initial: true)
      assert is_pid(pid)
      Agent.stop(pid)
    end

    test "__using__ generates call/2 function (can be overridden)" do
      conn = %Plug.Conn{}
      result = TestPlugin1.call(conn, test: true)
      assert result.private[:plugin_called] == true
    end

    test "init/1 can be overridden" do
      result = TestPlugin2.init(base: true)
      assert result[:custom_init] == true
    end

    test "call/2 can be overridden" do
      conn = %Plug.Conn{}
      result = TestPlugin2.call(conn, test: true)
      assert result.private[:opts] == [test: true]
    end

    test "default call/2 returns conn unchanged" do
      conn = %Plug.Conn{}
      assert TestPlugin3.call(conn, []) == conn
    end
  end
end
