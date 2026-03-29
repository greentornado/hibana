defmodule Hibana.WebSocketTest do
  use ExUnit.Case, async: true
  use Hibana.TestHelpers

  alias Hibana.WebSocket

  describe "WebSocket behaviour callbacks" do
    test "defines all required callbacks" do
      callbacks = WebSocket.behaviour_info(:callbacks)

      required = [
        {:init, 2},
        {:handle_connect, 2},
        {:handle_disconnect, 2},
        {:handle_in, 2},
        {:handle_binary, 2},
        {:handle_info, 2}
      ]

      for {name, arity} <- required do
        assert Enum.any?(callbacks, fn {n, a} -> n == name && a == arity end),
               "Expected callback #{name}/#{arity} to be defined"
      end
    end
  end

  describe "__using__ macro" do
    test "provides default init/2 implementation" do
      defmodule DefaultInitSocket do
        use WebSocket
      end

      conn = conn(:get, "/ws")
      assert DefaultInitSocket.init(conn, []) == {:ok, conn, %{}}
    end

    test "provides default handle_connect/2 implementation" do
      defmodule DefaultConnectSocket do
        use WebSocket
      end

      assert DefaultConnectSocket.handle_connect([], %{}) == {:ok, %{}}
    end

    test "provides default handle_disconnect/2 implementation" do
      defmodule DefaultDisconnectSocket do
        use WebSocket
      end

      assert DefaultDisconnectSocket.handle_disconnect(:normal, %{}) == {:ok, %{}}
    end

    test "provides default handle_in/2 implementation" do
      defmodule DefaultInSocket do
        use WebSocket
      end

      assert DefaultInSocket.handle_in("message", %{}) == {:ok, %{}}
    end

    test "provides default handle_binary/2 implementation" do
      defmodule DefaultBinarySocket do
        use WebSocket
      end

      assert DefaultBinarySocket.handle_binary(<<1, 2, 3>>, %{}) == {:ok, %{}}
    end

    test "provides default handle_info/2 implementation" do
      defmodule DefaultInfoSocket do
        use WebSocket
      end

      assert DefaultInfoSocket.handle_info(:msg, %{}) == {:ok, %{}}
    end

    test "init/2 can be overridden" do
      defmodule CustomInitSocket do
        use WebSocket

        def init(conn, opts) do
          {:ok, conn, %{custom: true, opts: opts}}
        end
      end

      conn = conn(:get, "/ws")

      assert CustomInitSocket.init(conn, test: true) ==
               {:ok, conn, %{custom: true, opts: [test: true]}}
    end

    test "handle_in/2 can be overridden" do
      defmodule EchoSocket do
        use WebSocket

        def handle_in(message, state) do
          {:reply, {:text, "Echo: " <> message}, state}
        end
      end

      assert EchoSocket.handle_in("hello", %{}) == {:reply, {:text, "Echo: hello"}, %{}}
    end

    test "handle_binary/2 can be overridden" do
      defmodule BinaryEchoSocket do
        use WebSocket

        def handle_binary(data, state) do
          {:reply, {:binary, data}, state}
        end
      end

      assert BinaryEchoSocket.handle_binary(<<1, 2, 3>>, %{}) ==
               {:reply, {:binary, <<1, 2, 3>>}, %{}}
    end

    test "handle_info/2 can be overridden" do
      defmodule InfoHandlerSocket do
        use WebSocket

        def handle_info({:broadcast, msg}, state) do
          {:push, {:text, msg}, state}
        end
      end

      assert InfoHandlerSocket.handle_info({:broadcast, "news"}, %{}) ==
               {:push, {:text, "news"}, %{}}
    end
  end

  describe "WebSocket implementations" do
    test "can create custom WebSocket handler" do
      defmodule CustomSocket do
        use WebSocket

        def init(conn, _opts) do
          # For test connections, use query_string parsing
          query_params = conn.query_string |> Plug.Conn.Query.decode()
          room = query_params["room"] || "general"
          {:ok, conn, %{room: room, user: nil}}
        end

        def handle_connect(_headers, state) do
          {:ok, Map.put(state, :connected, true)}
        end

        def handle_in(message, state) do
          {:reply, {:text, "Received: " <> message}, state}
        end

        def handle_disconnect(_reason, state) do
          {:ok, Map.put(state, :connected, false)}
        end
      end

      conn = conn(:get, "/ws?room=lobby")
      assert CustomSocket.init(conn, []) == {:ok, conn, %{room: "lobby", user: nil}}
      assert CustomSocket.handle_connect([], %{}) == {:ok, %{connected: true}}
      assert CustomSocket.handle_in("hello", %{}) == {:reply, {:text, "Received: hello"}, %{}}
      assert CustomSocket.handle_disconnect(:normal, %{}) == {:ok, %{connected: false}}
    end

    test "can handle state changes" do
      defmodule StateSocket do
        use WebSocket

        def handle_in("increment", state) do
          count = Map.get(state, :count, 0) + 1
          {:reply, {:text, "Count: #{count}"}, Map.put(state, :count, count)}
        end

        def handle_in("decrement", state) do
          count = Map.get(state, :count, 0) - 1
          {:reply, {:text, "Count: #{count}"}, Map.put(state, :count, count)}
        end
      end

      state1 = %{count: 0}
      {:reply, {:text, "Count: 1"}, state2} = StateSocket.handle_in("increment", state1)
      assert state2.count == 1

      {:reply, {:text, "Count: 0"}, state3} = StateSocket.handle_in("decrement", state2)
      assert state3.count == 0
    end

    test "can broadcast to other clients" do
      defmodule BroadcastSocket do
        use WebSocket

        def handle_info({:broadcast, msg, from}, state) do
          if from != state[:user_id] do
            {:push, {:text, msg}, state}
          else
            {:ok, state}
          end
        end
      end

      assert BroadcastSocket.handle_info({:broadcast, "hello", "user1"}, %{user_id: "user2"}) ==
               {:push, {:text, "hello"}, %{user_id: "user2"}}

      assert BroadcastSocket.handle_info({:broadcast, "hello", "user1"}, %{user_id: "user1"}) ==
               {:ok, %{user_id: "user1"}}
    end
  end

  describe "WebSocket return values" do
    test "handle_in can return {:ok, state}" do
      defmodule OkSocket do
        use WebSocket

        def handle_in(_msg, state) do
          {:ok, state}
        end
      end

      assert OkSocket.handle_in("test", %{}) == {:ok, %{}}
    end

    test "handle_in can return {:reply, message, state}" do
      defmodule ReplySocket do
        use WebSocket

        def handle_in(_msg, state) do
          {:reply, {:text, "response"}, state}
        end
      end

      assert ReplySocket.handle_in("test", %{}) == {:reply, {:text, "response"}, %{}}
    end

    test "handle_in can return {:stop, state}" do
      defmodule StopSocket do
        use WebSocket

        def handle_in("quit", state) do
          {:stop, state}
        end
      end

      assert StopSocket.handle_in("quit", %{}) == {:stop, %{}}
    end
  end

  describe "WebSocket upgrade" do
    test "upgrade adds private fields to conn" do
      defmodule UpgradeSocket do
        use WebSocket
      end

      conn = conn(:get, "/ws")
      upgraded_conn = WebSocket.upgrade(conn, UpgradeSocket, opt: true)

      assert upgraded_conn.private[:websocket_handler] == UpgradeSocket
      assert upgraded_conn.private[:websocket_handler_opts] == [opt: true]
    end

    test "upgrade with default opts" do
      defmodule DefaultUpgradeSocket do
        use WebSocket
      end

      conn = conn(:get, "/ws")
      upgraded_conn = WebSocket.upgrade(conn, DefaultUpgradeSocket)

      assert upgraded_conn.private[:websocket_handler] == DefaultUpgradeSocket
      assert upgraded_conn.private[:websocket_handler_opts] == []
    end
  end

  describe "WebSocket message types" do
    test "can handle text messages" do
      defmodule TextSocket do
        use WebSocket

        def handle_in("ping", state) do
          {:reply, {:text, "pong"}, state}
        end

        def handle_in(msg, state) do
          {:reply, {:text, "Received: #{msg}"}, state}
        end
      end

      assert TextSocket.handle_in("ping", %{}) == {:reply, {:text, "pong"}, %{}}
      assert TextSocket.handle_in("hello", %{}) == {:reply, {:text, "Received: hello"}, %{}}
    end

    test "can handle binary messages" do
      defmodule BinaryHandlerSocket do
        use WebSocket

        def handle_binary(<<0x01>>, state) do
          {:reply, {:binary, <<0x02>>}, state}
        end

        def handle_binary(data, state) do
          {:reply, {:binary, data}, state}
        end
      end

      assert BinaryHandlerSocket.handle_binary(<<0x01>>, %{}) ==
               {:reply, {:binary, <<0x02>>}, %{}}

      assert BinaryHandlerSocket.handle_binary(<<1, 2, 3>>, %{}) ==
               {:reply, {:binary, <<1, 2, 3>>}, %{}}
    end

    test "can handle JSON messages" do
      defmodule JsonSocket do
        use WebSocket

        def handle_in(msg, state) do
          case Jason.decode(msg) do
            {:ok, %{"type" => "greet", "name" => name}} ->
              {:reply, {:text, Jason.encode!(%{type: "greeting", message: "Hello, #{name}!"})},
               state}

            _ ->
              {:reply, {:text, "Invalid JSON"}, state}
          end
        end
      end

      json_msg = ~s({"type": "greet", "name": "Alice"})
      {:reply, {:text, response}, _} = JsonSocket.handle_in(json_msg, %{})
      assert Jason.decode!(response)["message"] == "Hello, Alice!"
    end
  end

  describe "WebSocket connection lifecycle" do
    test "init can halt connection" do
      defmodule HaltInitSocket do
        use WebSocket

        def init(conn, _opts) do
          query_params = conn.query_string |> Plug.Conn.Query.decode()

          if query_params["auth"] != "valid" do
            {:halt, Plug.Conn.send_resp(conn, 403, "Forbidden")}
          else
            {:ok, conn, %{}}
          end
        end
      end

      conn = conn(:get, "/ws?auth=invalid")
      assert {:halt, halted_conn} = HaltInitSocket.init(conn, [])
      assert halted_conn.status == 403
    end

    test "handle_connect can stop connection" do
      defmodule StopConnectSocket do
        use WebSocket

        def handle_connect(_headers, state) do
          if state[:banned] do
            {:stop, state}
          else
            {:ok, state}
          end
        end
      end

      assert StopConnectSocket.handle_connect([], %{banned: true}) == {:stop, %{banned: true}}
      assert StopConnectSocket.handle_connect([], %{banned: false}) == {:ok, %{banned: false}}
    end
  end

  describe "WebSocket patterns" do
    test "heartbeat/ping-pong pattern" do
      defmodule HeartbeatSocket do
        use WebSocket

        def handle_in("ping", state) do
          last_ping = System.monotonic_time(:second)
          {:reply, {:text, "pong"}, Map.put(state, :last_ping, last_ping)}
        end
      end

      before = System.monotonic_time(:second)
      {:reply, {:text, "pong"}, state} = HeartbeatSocket.handle_in("ping", %{})
      assert state[:last_ping] >= before
    end

    test "room-based messaging" do
      defmodule RoomSocket do
        use WebSocket

        def init(conn, _opts) do
          query_params = conn.query_string |> Plug.Conn.Query.decode()
          room = query_params["room"] || "general"
          {:ok, conn, %{room: room, users: []}}
        end

        def handle_in("/join " <> username, state) do
          {:reply, {:text, "#{username} joined #{state.room}"},
           Map.update!(state, :users, &[username | &1])}
        end

        def handle_in("/leave " <> username, state) do
          {:reply, {:text, "#{username} left #{state.room}"},
           Map.update!(state, :users, &List.delete(&1, username))}
        end
      end

      conn = conn(:get, "/ws?room=lobby")
      {:ok, _, state} = RoomSocket.init(conn, [])

      {:reply, {:text, "Alice joined lobby"}, state2} = RoomSocket.handle_in("/join Alice", state)
      assert state2.users == ["Alice"]

      {:reply, {:text, "Bob joined lobby"}, state3} = RoomSocket.handle_in("/join Bob", state2)
      assert state3.users == ["Bob", "Alice"]

      {:reply, {:text, "Alice left lobby"}, state4} = RoomSocket.handle_in("/leave Alice", state3)
      assert state4.users == ["Bob"]
    end
  end

  describe "WebSocket adapter selection" do
    test "automatic adapter selection" do
      # The adapter is selected based on whether Bandit is loaded
      # We can't easily test this without mocking, but we can verify
      # the upgrade function works
      defmodule AdapterTestSocket do
        use WebSocket
      end

      conn = conn(:get, "/ws")
      upgraded = WebSocket.upgrade(conn, AdapterTestSocket)

      # Verify the conn was properly set up for upgrade
      assert upgraded.private[:websocket_handler] == AdapterTestSocket
    end
  end
end
