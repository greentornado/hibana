defmodule Hibana.GenServerMacroTest do
  @moduledoc """
  Tests to force Hibana.GenServer macro execution for coverage.
  Modules defined at compile time to ensure macro code is executed.
  """
  use ExUnit.Case, async: true

  # Define test modules at compile time to force macro execution
  defmodule TestGenServer1 do
    use Hibana.GenServer

    def handle_call(:test, _from, state) do
      {:reply, :ok, state}
    end
  end

  defmodule TestGenServer2 do
    use Hibana.GenServer

    def init(opts) do
      {:ok, Keyword.put(opts, :initialized, true)}
    end

    def handle_call(:get, _from, state) do
      {:reply, state, state}
    end
  end

  describe "GenServer macro execution" do
    test "__using__ generates start_link/1 function" do
      {:ok, pid} = TestGenServer1.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "__using__ generates default init/1" do
      {:ok, pid} = TestGenServer1.start_link(test: true)
      # Default init returns opts as state
      assert GenServer.call(pid, :test) == :ok
      GenServer.stop(pid)
    end

    test "init/1 can be overridden" do
      {:ok, pid} = TestGenServer2.start_link(base: true)
      state = GenServer.call(pid, :get)
      assert state[:initialized] == true
      assert state[:base] == true
      GenServer.stop(pid)
    end

    test "start_link/1 can be overridden" do
      defmodule TestGenServer3 do
        use Hibana.GenServer

        def start_link(opts) do
          GenServer.start_link(__MODULE__, opts, name: :custom_name)
        end

        def handle_call(:ping, _from, state) do
          {:reply, :pong, state}
        end
      end

      {:ok, pid} = TestGenServer3.start_link([])
      assert GenServer.call(pid, :ping) == :pong
      GenServer.stop(pid)
    end
  end
end
