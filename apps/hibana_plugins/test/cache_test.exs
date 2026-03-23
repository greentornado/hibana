defmodule Hibana.Plugins.CacheTest do
  use ExUnit.Case, async: false

  setup do
    if :ets.whereis(:hibana_cache) != :undefined do
      :ets.delete(:hibana_cache)
    end

    :ets.new(:hibana_cache, [:set, :named_table, :public, {:read_concurrency, true}])

    on_exit(fn ->
      if :ets.whereis(:hibana_cache) != :undefined do
        :ets.delete(:hibana_cache)
      end
    end)

    :ok
  end

  describe "init/1" do
    test "sets default options" do
      opts = Hibana.Plugins.Cache.init([])
      assert opts.ttl == 300_000
      assert opts.max_size == 1000
    end

    test "allows custom options" do
      opts = Hibana.Plugins.Cache.init(ttl: 60_000, max_size: 500)
      assert opts.ttl == 60_000
      assert opts.max_size == 500
    end
  end

  describe "start_link/0" do
    test "starts the cache table" do
      # Delete the table created in setup so start_link can recreate it
      :ets.delete(:hibana_cache)
      result = Hibana.Plugins.Cache.start_link()
      assert result == {:ok, self()}
    end
  end

  describe "get/1" do
    test "returns nil for missing key" do
      {:ok, result} = Hibana.Plugins.Cache.get("missing")
      assert result == nil
    end

    test "returns value for existing key" do
      :ets.insert(:hibana_cache, {"key1", "value1", 999_999_999_999_999})
      {:ok, result} = Hibana.Plugins.Cache.get("key1")
      assert result == "value1"
    end

    test "returns nil for expired key" do
      past_expiry = System.system_time(:millisecond) - 1000
      :ets.insert(:hibana_cache, {"expired_key", "value", past_expiry})
      {:ok, result} = Hibana.Plugins.Cache.get("expired_key")
      assert result == nil
    end
  end

  describe "set/3" do
    test "stores value with key" do
      :ok = Hibana.Plugins.Cache.set("key", "value")
      {:ok, result} = Hibana.Plugins.Cache.get("key")
      assert result == "value"
    end

    test "stores value with custom TTL" do
      :ok = Hibana.Plugins.Cache.set("ttl_key", "value", 5000)
      {:ok, result} = Hibana.Plugins.Cache.get("ttl_key")
      assert result == "value"
    end
  end

  describe "delete/1" do
    test "removes key from cache" do
      :ok = Hibana.Plugins.Cache.set("key", "value")
      :ok = Hibana.Plugins.Cache.delete("key")
      {:ok, result} = Hibana.Plugins.Cache.get("key")
      assert result == nil
    end
  end

  describe "exists?/1" do
    test "returns true for existing non-expired key" do
      :ets.insert(:hibana_cache, {"key1", "value1", 999_999_999_999_999})
      assert Hibana.Plugins.Cache.exists?("key1") == true
    end

    test "returns false for missing key" do
      assert Hibana.Plugins.Cache.exists?("missing") == false
    end

    test "returns false for expired key" do
      past_expiry = System.system_time(:millisecond) - 1000
      :ets.insert(:hibana_cache, {"expired_key", "value", past_expiry})
      assert Hibana.Plugins.Cache.exists?("expired_key") == false
    end
  end

  describe "get_or_compute/3" do
    test "returns existing value without computing" do
      future_expiry = System.system_time(:millisecond) + 60_000
      :ets.insert(:hibana_cache, {"key1", "cached", future_expiry})
      compute_called = :counters.new(1, [:atomics])
      :counters.add(compute_called, 1, 1)

      {:ok, result} =
        Hibana.Plugins.Cache.get_or_compute("key1", 60_000, fn ->
          :counters.add(compute_called, 1, 1)
          "computed"
        end)

      assert result == "cached"
      assert :counters.get(compute_called, 1) == 1
    end

    test "computes and stores value when missing" do
      {:ok, result} =
        Hibana.Plugins.Cache.get_or_compute("new_key", 60_000, fn ->
          "computed_value"
        end)

      assert result == "computed_value"
    end
  end

  describe "clear/0" do
    test "removes all entries" do
      Hibana.Plugins.Cache.set("key1", "value1")
      Hibana.Plugins.Cache.set("key2", "value2")
      :ok = Hibana.Plugins.Cache.clear()
      {:ok, result1} = Hibana.Plugins.Cache.get("key1")
      {:ok, result2} = Hibana.Plugins.Cache.get("key2")
      assert result1 == nil
      assert result2 == nil
    end
  end

  describe "stats/0" do
    test "returns cache statistics" do
      Hibana.Plugins.Cache.set("key1", "value1")
      stats = Hibana.Plugins.Cache.stats()
      assert is_map(stats)
      assert stats.size >= 1
      assert stats.memory >= 0
    end
  end

  describe "cleanup/0" do
    test "removes expired entries" do
      past_expiry = System.system_time(:millisecond) - 1000
      :ets.insert(:hibana_cache, {"expired1", "v1", past_expiry})
      :ets.insert(:hibana_cache, {"expired2", "v2", past_expiry})
      future_expiry = System.system_time(:millisecond) + 60_000
      :ets.insert(:hibana_cache, {"valid", "v3", future_expiry})

      :ok = Hibana.Plugins.Cache.cleanup()

      {:ok, r1} = Hibana.Plugins.Cache.get("expired1")
      {:ok, r2} = Hibana.Plugins.Cache.get("expired2")
      {:ok, r3} = Hibana.Plugins.Cache.get("valid")
      assert r1 == nil
      assert r2 == nil
      assert r3 == "v3"
    end
  end

  describe "call/2" do
    test "returns conn unchanged" do
      conn = Plug.Test.conn(:get, "/")
      opts = %{ttl: 60_000, max_size: 500}
      result = Hibana.Plugins.Cache.call(conn, opts)
      assert result == conn
    end
  end
end
