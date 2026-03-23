defmodule Hibana.GenServerTest do
  use ExUnit.Case, async: true

  defmodule TestGenServer do
    use Hibana.GenServer

    def start_link(opts) do
      GenServer.start_link(__MODULE__, [], opts)
    end

    @impl true
    def init(state) do
      {:ok, state}
    end

    def get_state(pid) do
      GenServer.call(pid, :get_state)
    end

    @impl true
    def handle_call(:get_state, _from, state) do
      {:reply, state, state}
    end
  end

  describe "GenServer macro" do
    test "starts linked process" do
      {:ok, pid} = TestGenServer.start_link(name: nil)
      assert is_pid(pid)
    end

    test "maintains state" do
      {:ok, pid} = TestGenServer.start_link(name: nil)
      assert TestGenServer.get_state(pid) == []
    end
  end
end
