defmodule Hibana.WebSocket.BanditAdapterTest do
  use ExUnit.Case, async: true

  alias Hibana.WebSocket.BanditAdapter

  # Mock handler for testing
  defmodule MockHandler do
    def init(_conn, opts) do
      {:ok, %{}, %{opts: opts, connected: false}}
    end

    def handle_connect(_headers, state) do
      {:ok, %{state | connected: true}}
    end

    def handle_in("ping", state) do
      {:reply, {:text, "pong"}, state}
    end

    def handle_in(message, state) do
      {:reply, {:text, "Echo: #{message}"}, state}
    end

    def handle_binary(data, state) do
      {:reply, {:binary, data}, state}
    end

    def handle_info({:custom, msg}, state) do
      {:push, {:text, "Info: #{msg}"}, state}
    end

    def handle_info(_msg, state) do
      {:ok, state}
    end

    def handle_disconnect(_reason, _state) do
      :ok
    end
  end

  describe "BanditAdapter.init/1" do
    test "initializes successfully with valid handler" do
      result = BanditAdapter.init({MockHandler, [test: true]})
      assert {:ok, state} = result
      assert state.handler == MockHandler
      assert state.state.opts == [test: true]
      assert state.state.connected == true
    end

    test "stops when handler returns halt" do
      defmodule HaltingHandler do
        def init(_conn, _opts), do: {:halt, %{}}
        def handle_disconnect(_reason, _state), do: :ok
      end

      result = BanditAdapter.init({HaltingHandler, []})
      assert {:stop, :normal, _state} = result
    end
  end

  describe "BanditAdapter.handle_in/2 - text messages" do
    setup do
      state = %{
        handler: MockHandler,
        handler_opts: [],
        state: %{opts: [], connected: true}
      }

      {:ok, state: state}
    end

    test "handles text message with reply", %{state: state} do
      result = BanditAdapter.handle_in({:text, "hello"}, state)
      assert {:reply, {:text, "Echo: hello"}, new_state} = result
      assert new_state.state.connected == true
    end

    test "handles stop response", %{state: state} do
      defmodule StopHandler do
        def handle_in(_msg, state), do: {:stop, state}
      end

      stop_state = %{state | handler: StopHandler}
      result = BanditAdapter.handle_in({:text, "stop"}, stop_state)
      assert {:stop, :normal, _} = result
    end

    test "handles invalid response gracefully", %{state: state} do
      defmodule InvalidHandler do
        def handle_in(_msg, state), do: {:invalid, state}
      end

      invalid_state = %{state | handler: InvalidHandler}
      result = BanditAdapter.handle_in({:text, "test"}, invalid_state)
      assert {:stop, :normal, _} = result
    end
  end

  describe "BanditAdapter.handle_in/2 - binary messages" do
    setup do
      state = %{
        handler: MockHandler,
        handler_opts: [],
        state: %{opts: [], connected: true}
      }

      {:ok, state: state}
    end

    test "handles binary message", %{state: state} do
      binary_data = <<1, 2, 3, 4>>
      result = BanditAdapter.handle_in({:binary, binary_data}, state)
      assert {:reply, {:binary, ^binary_data}, _} = result
    end
  end

  describe "BanditAdapter.handle_in/2 - ping/pong" do
    setup do
      state = %{
        handler: MockHandler,
        handler_opts: [],
        state: %{opts: [], connected: true}
      }

      {:ok, state: state}
    end

    test "responds to ping with pong", %{state: state} do
      result = BanditAdapter.handle_in({:ping, <<>>}, state)
      assert {:reply, {:pong, <<>>}, ^state} = result
    end

    test "handles pong silently", %{state: state} do
      result = BanditAdapter.handle_in({:pong, <<>>}, state)
      assert {[], ^state} = result
    end
  end

  describe "BanditAdapter.handle_info/2" do
    setup do
      state = %{
        handler: MockHandler,
        handler_opts: [],
        state: %{opts: [], connected: true}
      }

      {:ok, state: state}
    end

    test "handles push message", %{state: state} do
      result = BanditAdapter.handle_info({:custom, "test"}, state)
      assert {:push, {:text, "Info: test"}, _} = result
    end

    test "handles ok response", %{state: state} do
      result = BanditAdapter.handle_info({:other, "msg"}, state)
      assert {:ok, _} = result
    end
  end

  describe "BanditAdapter.terminate/2" do
    test "calls handler disconnect callback" do
      state = %{
        handler: MockHandler,
        handler_opts: [],
        state: %{opts: [], connected: true}
      }

      result = BanditAdapter.terminate({:normal, :shutdown}, state)
      assert :ok = result
    end
  end
end
