defmodule Hibana.WebSocketTest do
  use ExUnit.Case, async: true

  describe "__using__/1" do
    test "creates default implementations for WebSocket callbacks" do
      defmodule TestSocketHandler do
        use Hibana.WebSocket
      end

      assert function_exported?(TestSocketHandler, :init, 2)
      assert function_exported?(TestSocketHandler, :handle_connect, 2)
      assert function_exported?(TestSocketHandler, :handle_disconnect, 2)
      assert function_exported?(TestSocketHandler, :handle_in, 2)
      assert function_exported?(TestSocketHandler, :handle_binary, 2)
      assert function_exported?(TestSocketHandler, :handle_info, 2)
    end

    test "default init returns ok with empty state" do
      defmodule TestSocketHandlerInit do
        use Hibana.WebSocket
      end

      conn = %Plug.Conn{}
      {:ok, _conn, state} = TestSocketHandlerInit.init(conn, [])
      assert state == %{}
    end

    test "default handle_connect returns ok with state" do
      defmodule TestSocketHandlerConnect do
        use Hibana.WebSocket
      end

      {:ok, state} = TestSocketHandlerConnect.handle_connect(:info, %{})
      assert state == %{}
    end

    test "default handle_in returns ok with state" do
      defmodule TestSocketHandlerIn do
        use Hibana.WebSocket
      end

      {:ok, state} = TestSocketHandlerIn.handle_in("hello", %{})
      assert state == %{}
    end

    test "callbacks are overridable" do
      defmodule CustomSocketHandler do
        use Hibana.WebSocket

        def init(conn, _opts) do
          {:ok, conn, %{custom: true}}
        end

        def handle_connect(_info, state) do
          {:ok, Map.put(state, :connected, true)}
        end
      end

      conn = %Plug.Conn{}
      {:ok, _conn, state} = CustomSocketHandler.init(conn, [])
      assert state == %{custom: true}

      {:ok, new_state} = CustomSocketHandler.handle_connect(:info, %{})
      assert new_state == %{connected: true}
    end
  end

  describe "behaviour callbacks exist" do
    test "WebSocket behaviour defines expected callbacks" do
      callbacks = Hibana.WebSocket.behaviour_info(:callbacks)

      expected_callbacks = [
        :init,
        :handle_connect,
        :handle_disconnect,
        :handle_in,
        :handle_binary,
        :handle_info
      ]

      for callback <- expected_callbacks do
        assert Enum.any?(callbacks, fn {name, _} -> name == callback end)
      end
    end
  end

  describe "start_link/2" do
    test "function exists" do
      Code.ensure_loaded!(Hibana.WebSocket)
      assert function_exported?(Hibana.WebSocket, :start_link, 2)
    end
  end
end
