defmodule Hibana.PluginTest do
  use ExUnit.Case, async: true
  use Hibana.TestHelpers

  alias Hibana.Plugin

  describe "Plugin behaviour callbacks" do
    test "defines init/1 callback" do
      callbacks = Plugin.behaviour_info(:callbacks)
      assert Enum.any?(callbacks, fn {name, arity} -> name == :init && arity == 1 end)
    end

    test "defines call/2 callback" do
      callbacks = Plugin.behaviour_info(:callbacks)
      assert Enum.any?(callbacks, fn {name, arity} -> name == :call && arity == 2 end)
    end

    test "defines before_send/2 callback as optional" do
      optional = Plugin.behaviour_info(:optional_callbacks)
      assert Enum.any?(optional, fn {name, arity} -> name == :before_send && arity == 2 end)
    end

    test "defines start_link/1 callback as optional" do
      optional = Plugin.behaviour_info(:optional_callbacks)
      assert Enum.any?(optional, fn {name, arity} -> name == :start_link && arity == 1 end)
    end
  end

  describe "__using__ macro" do
    test "provides default init/1 implementation" do
      defmodule DefaultInitPlugin do
        use Plugin

        def call(conn, _opts), do: conn
      end

      assert DefaultInitPlugin.init(custom: true) == [custom: true]
    end

    test "provides default before_send/2 implementation" do
      defmodule DefaultBeforeSendPlugin do
        use Plugin

        def call(conn, _opts), do: conn
      end

      conn = conn(:get, "/")
      assert DefaultBeforeSendPlugin.before_send(conn, []) == conn
    end

    test "provides default start_link/1 implementation" do
      defmodule DefaultStartLinkPlugin do
        use Plugin

        def call(conn, _opts), do: conn
      end

      {:ok, pid} = DefaultStartLinkPlugin.start_link(test: true)
      assert is_pid(pid)
      assert Process.alive?(pid)
      Agent.stop(pid)
    end

    test "call/2 must be implemented" do
      defmodule MinimalPlugin do
        use Plugin

        def call(conn, _opts) do
          Plug.Conn.assign(conn, :plugin_called, true)
        end
      end

      conn = conn(:get, "/")
      new_conn = MinimalPlugin.call(conn, [])
      assert new_conn.assigns[:plugin_called] == true
    end

    test "init/1 can be overridden" do
      defmodule CustomInitPlugin do
        use Plugin

        def init(opts) do
          Keyword.put(opts, :initialized, true)
        end

        def call(conn, _opts), do: conn
      end

      result = CustomInitPlugin.init(custom: true)
      assert result[:initialized] == true
    end

    test "before_send/2 can be overridden" do
      defmodule CustomBeforeSendPlugin do
        use Plugin

        def call(conn, _opts), do: conn

        def before_send(conn, _opts) do
          Plug.Conn.put_resp_header(conn, "x-custom", "value")
        end
      end

      conn = conn(:get, "/")
      new_conn = CustomBeforeSendPlugin.before_send(conn, [])
      assert Plug.Conn.get_resp_header(new_conn, "x-custom") == ["value"]
    end

    test "start_link/1 can be overridden" do
      defmodule CustomStartLinkPlugin do
        use Plugin

        def call(conn, _opts), do: conn

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: __MODULE__)
        end

        def init(opts), do: {:ok, opts}
      end

      {:ok, pid} = CustomStartLinkPlugin.start_link(test: true)
      assert is_pid(pid)
      GenServer.stop(pid)
    end
  end

  describe "Plugin implementations" do
    test "plugin can modify connection" do
      defmodule ModifyConnPlugin do
        use Plugin

        def call(conn, _opts) do
          conn
          |> Plug.Conn.put_status(200)
          |> Plug.Conn.assign(:modified, true)
        end
      end

      conn = conn(:get, "/")
      new_conn = ModifyConnPlugin.call(conn, [])
      assert new_conn.status == 200
      assert new_conn.assigns[:modified] == true
    end

    test "plugin can halt connection" do
      defmodule HaltPlugin do
        use Plugin

        def call(conn, _opts) do
          conn
          |> Plug.Conn.send_resp(403, "Forbidden")
          |> Plug.Conn.halt()
        end
      end

      conn = conn(:get, "/")
      new_conn = HaltPlugin.call(conn, [])
      assert new_conn.halted == true
      assert new_conn.status == 403
    end

    test "plugin chain works correctly" do
      defmodule ChainPlugin1 do
        use Plugin

        def call(conn, _opts) do
          Plug.Conn.assign(conn, :step1, true)
        end
      end

      defmodule ChainPlugin2 do
        use Plugin

        def call(conn, _opts) do
          Plug.Conn.assign(conn, :step2, true)
        end
      end

      conn = conn(:get, "/")
      conn = ChainPlugin1.call(conn, [])
      conn = ChainPlugin2.call(conn, [])

      assert conn.assigns[:step1] == true
      assert conn.assigns[:step2] == true
    end
  end

  describe "Plugin with options" do
    test "plugin receives options in init" do
      defmodule OptionsPlugin do
        use Plugin

        def init(opts) do
          Keyword.put(opts, :received, true)
        end

        def call(conn, _opts), do: conn
      end

      result = OptionsPlugin.init(key: "value")
      assert result[:key] == "value"
      assert result[:received] == true
    end

    test "plugin receives options in call" do
      defmodule CallOptionsPlugin do
        use Plugin

        def call(conn, opts) do
          Plug.Conn.assign(conn, :options, opts)
        end
      end

      conn = conn(:get, "/")
      new_conn = CallOptionsPlugin.call(conn, custom: true)
      assert new_conn.assigns[:options] == [custom: true]
    end

    test "plugin receives options in before_send" do
      defmodule BeforeSendOptionsPlugin do
        use Plugin

        def call(conn, _opts), do: conn

        def before_send(conn, opts) do
          Plug.Conn.assign(conn, :before_options, opts)
        end
      end

      conn = conn(:get, "/")
      new_conn = BeforeSendOptionsPlugin.before_send(conn, response: true)
      assert new_conn.assigns[:before_options] == [response: true]
    end
  end

  describe "Plugin error handling" do
    test "plugin can handle errors gracefully" do
      defmodule ErrorHandlingPlugin do
        use Plugin

        def call(conn, _opts) do
          try do
            # Simulate some work that might fail
            risky_operation()
            conn
          rescue
            _ -> Plug.Conn.send_resp(conn, 500, "Error")
          end
        end

        defp risky_operation do
          # This would fail in real scenario
          :ok
        end
      end

      conn = conn(:get, "/")
      new_conn = ErrorHandlingPlugin.call(conn, [])
      assert new_conn.status != 500
    end
  end

  describe "Plugin state management" do
    test "plugin can maintain state via Agent" do
      defmodule StatefulPlugin do
        use Plugin

        def call(conn, _opts) do
          # Access state from Agent
          state = Agent.get(__MODULE__, & &1)
          Plug.Conn.assign(conn, :state, state)
        end
      end

      # Start the plugin
      {:ok, pid} = StatefulPlugin.start_link(count: 0)

      conn = conn(:get, "/")
      new_conn = StatefulPlugin.call(conn, [])
      assert new_conn.assigns[:state] == [count: 0]

      Agent.stop(pid)
    end
  end
end
