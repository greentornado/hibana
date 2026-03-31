defmodule Hibana.ClusterTest do
  use ExUnit.Case

  alias Hibana.Cluster

  # Start registry for each test
  setup do
    # Ensure Registry is started before Cluster
    case Registry.start_link(keys: :duplicate, name: Hibana.Cluster.PubSub) do
      {:ok, _} -> :ok
      {:error, {:already_started, _}} -> :ok
    end

    :ok
  end

  describe "start_link/1" do
    setup do
      # Ensure Registry is started for each test in this describe
      case Registry.start_link(keys: :duplicate, name: Hibana.Cluster.PubSub) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      :ok
    end

    test "starts with epmd strategy" do
      {:ok, pid} = Cluster.start_link(strategy: :epmd, hosts: [])
      assert Process.alive?(pid)

      :ok = GenServer.stop(pid)
    end

    test "starts and falls back to epmd for dns strategy" do
      {:ok, pid} = Cluster.start_link(strategy: :dns, query: "test.local")
      assert Process.alive?(pid)

      :ok = GenServer.stop(pid)
    end

    test "starts and falls back to epmd for gossip strategy" do
      {:ok, pid} = Cluster.start_link(strategy: :gossip, port: 0)
      assert Process.alive?(pid)

      :ok = GenServer.stop(pid)
    end

    test "raises error for unknown strategy" do
      assert_raise ArgumentError, fn ->
        Cluster.start_link(strategy: :unknown)
      end
    end
  end

  describe "PubSub operations" do
    setup do
      # Ensure Registry is started
      case Registry.start_link(keys: :duplicate, name: Hibana.Cluster.PubSub) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      {:ok, pid} = Cluster.start_link(name: :test_cluster, hosts: [])

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end

        # Note: We keep Registry alive for other tests
      end)

      {:ok, pid: pid}
    end

    test "subscribe to topic", %{pid: _pid} do
      :ok = Cluster.subscribe("test:topic")
      # Should be able to subscribe multiple times
      :ok = Cluster.subscribe("test:topic")
    end

    test "unsubscribe from topic", %{pid: _pid} do
      Cluster.subscribe("test:topic")
      :ok = Cluster.unsubscribe("test:topic")
    end

    test "publish message to topic", %{pid: _pid} do
      Cluster.subscribe("pub:topic")
      :ok = Cluster.publish("pub:topic", %{message: "hello"})
    end

    test "broadcast message locally", %{pid: _pid} do
      :ok = Cluster.local_broadcast("local:topic", %{data: "test"})
    end
  end

  describe "node operations" do
    setup do
      # Ensure Registry is started
      case Registry.start_link(keys: :duplicate, name: Hibana.Cluster.PubSub) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      {:ok, pid} = Cluster.start_link(name: :test_cluster_nodes, hosts: [])

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end
      end)

      {:ok, pid: pid}
    end

    test "lists nodes", %{pid: _pid} do
      nodes = Cluster.nodes()
      assert is_list(nodes)
    end

    test "gets node count", %{pid: _pid} do
      count = Cluster.node_count()
      assert is_integer(count)
      assert count >= 1
    end

    test "checks health", %{pid: _pid} do
      # In test environment without distributed mode, Node.alive?() returns false
      # The function should still work without crashing
      result = Cluster.healthy?()
      assert is_boolean(result)
    end
  end

  describe "RPC operations" do
    setup do
      # Ensure Registry is started
      case Registry.start_link(keys: :duplicate, name: Hibana.Cluster.PubSub) do
        {:ok, _} -> :ok
        {:error, {:already_started, _}} -> :ok
      end

      {:ok, pid} = Cluster.start_link(name: :test_cluster_rpc, hosts: [])

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end
      end)

      {:ok, pid: pid}
    end

    test "calls function on node", %{pid: _pid} do
      # Call on current node - Kernel.+ is whitelisted by default
      result = Cluster.call_on(node(), Kernel, :+, [1, 2])
      assert result == 3
    end

    test "calls blocked for non-whitelisted functions", %{pid: _pid} do
      # Call on current node - non-whitelisted function should be blocked
      result = Cluster.call_on(node(), System, :cmd, ["echo", ["hello"]])
      assert result == {:error, :rpc_not_allowed}
    end

    test "casts function to node", %{pid: _pid} do
      # Cast returns true (always, since it's asynchronous) for whitelisted functions
      assert Cluster.cast_on(node(), Kernel, :+, [1, 2]) == true
    end

    test "multicall on all nodes", %{pid: _pid} do
      {results, bad_nodes} = Cluster.multicall(Kernel, :node, [])
      assert is_list(results)
      assert is_list(bad_nodes)
      assert length(results) >= 1
    end

    test "rpc whitelist configuration", %{pid: _pid} do
      whitelist = Cluster.get_rpc_whitelist()
      assert is_list(whitelist) or whitelist == :all
      # Kernel.+ should be in default whitelist
      assert Cluster.rpc_allowed?(Kernel, :+)
    end
  end
end
