defmodule Hibana.OTPCacheTest do
  use ExUnit.Case, async: false

  setup do
    name = :"cache_test_#{System.unique_integer([:positive])}"
    {:ok, pid} = Hibana.OTPCache.start_link(name: name)
    %{cache: pid, name: name}
  end

  describe "start_link/1" do
    test "starts with default name" do
      name = :"cache_start_#{System.unique_integer([:positive])}"
      {:ok, pid} = Hibana.OTPCache.start_link(name: name)
      assert is_pid(pid)
    end

    test "accepts max_size option" do
      name = :"cache_max_#{System.unique_integer([:positive])}"
      {:ok, pid} = Hibana.OTPCache.start_link(name: name, max_size: 100)
      assert is_pid(pid)
    end
  end

  describe "put/4" do
    test "stores value with key", %{name: name} do
      Hibana.OTPCache.put(name, :key, "value")
      assert Hibana.OTPCache.get(name, :key) == "value"
    end

    test "stores value with TTL", %{name: name} do
      Hibana.OTPCache.put(name, :ttl_key, "value", ttl: 5000)
      assert Hibana.OTPCache.get(name, :ttl_key) == "value"
    end

    test "overwrites existing value", %{name: name} do
      Hibana.OTPCache.put(name, :key, "value1")
      Hibana.OTPCache.put(name, :key, "value2")
      assert Hibana.OTPCache.get(name, :key) == "value2"
    end

    test "respects max_size limit by evicting oldest" do
      name = :"cache_evict_#{System.unique_integer([:positive])}"
      Hibana.OTPCache.start_link(name: name, max_size: 2)
      Hibana.OTPCache.put(name, :key1, "value1")
      Hibana.OTPCache.put(name, :key2, "value2")
      Hibana.OTPCache.put(name, :key3, "value3")
      assert Hibana.OTPCache.get(name, :key1) == nil
      assert Hibana.OTPCache.get(name, :key2) == "value2"
      assert Hibana.OTPCache.get(name, :key3) == "value3"
    end
  end

  describe "get/2" do
    test "returns nil for missing key", %{name: name} do
      assert Hibana.OTPCache.get(name, :missing) == nil
    end

    test "returns value for existing key", %{name: name} do
      Hibana.OTPCache.put(name, :key1, "value1")
      assert Hibana.OTPCache.get(name, :key1) == "value1"
    end

    test "returns nil for expired key", %{name: name} do
      Hibana.OTPCache.put(name, :expired, "value", ttl: 10)
      Process.sleep(20)
      assert Hibana.OTPCache.get(name, :expired) == nil
    end

    test "returns value with no expiry", %{name: name} do
      Hibana.OTPCache.put(name, :no_expiry, "value")
      assert Hibana.OTPCache.get(name, :no_expiry) == "value"
    end
  end

  describe "get_or_compute/4" do
    test "returns existing value without computing", %{name: name} do
      Hibana.OTPCache.put(name, :key, "cached")
      compute_called = :counters.new(1, [:atomics])

      {:ok, result} =
        Hibana.OTPCache.get_or_compute(
          name,
          :key,
          fn ->
            :counters.add(compute_called, 1, 1)
            "computed"
          end,
          ttl: 60_000
        )

      assert result == "cached"
      assert :counters.get(compute_called, 1) == 0
    end

    test "computes and stores value when missing", %{name: name} do
      {:ok, result} =
        Hibana.OTPCache.get_or_compute(name, :missing_key, fn ->
          "computed_value"
        end)

      assert result == "computed_value"
    end

    test "uses default TTL of 300000ms", %{name: name} do
      {:ok, _} = Hibana.OTPCache.get_or_compute(name, :key, fn -> "value" end)
      assert Hibana.OTPCache.get(name, :key) == "value"
    end
  end

  describe "delete/2" do
    test "removes key from cache", %{name: name} do
      Hibana.OTPCache.put(name, :key, "value")
      :ok = Hibana.OTPCache.delete(name, :key)
      assert Hibana.OTPCache.get(name, :key) == nil
    end
  end

  describe "exists?/2" do
    test "returns true for existing non-expired key", %{name: name} do
      Hibana.OTPCache.put(name, :key, "value")
      assert Hibana.OTPCache.exists?(name, :key) == true
    end

    test "returns false for missing key", %{name: name} do
      assert Hibana.OTPCache.exists?(name, :missing) == false
    end

    test "returns false for expired key", %{name: name} do
      Hibana.OTPCache.put(name, :expired, "value", ttl: 10)
      Process.sleep(20)
      assert Hibana.OTPCache.exists?(name, :expired) == false
    end

    test "returns true for key with no expiry", %{name: name} do
      Hibana.OTPCache.put(name, :no_expiry, "value")
      assert Hibana.OTPCache.exists?(name, :no_expiry) == true
    end
  end

  describe "clear/1" do
    test "removes all entries", %{name: name} do
      Hibana.OTPCache.put(name, :key1, "value1")
      Hibana.OTPCache.put(name, :key2, "value2")
      :ok = Hibana.OTPCache.clear(name)
      assert Hibana.OTPCache.get(name, :key1) == nil
      assert Hibana.OTPCache.get(name, :key2) == nil
    end
  end

  describe "stats/1" do
    test "returns cache statistics", %{name: name} do
      Hibana.OTPCache.put(name, :key1, "value1")
      Hibana.OTPCache.put(name, :key2, "value2")
      stats = Hibana.OTPCache.stats(name)
      assert stats.total == 2
      assert stats.valid == 2
      assert stats.max_size == 1000
    end

    test "shows expired entries as invalid", %{name: name} do
      Hibana.OTPCache.put(name, :valid, "value")
      Hibana.OTPCache.put(name, :expired, "value", ttl: 10)
      Process.sleep(20)
      stats = Hibana.OTPCache.stats(name)
      assert stats.valid < stats.total
    end
  end

  describe "keys/1" do
    test "returns all keys", %{name: name} do
      Hibana.OTPCache.put(name, :key1, "value1")
      Hibana.OTPCache.put(name, :key2, "value2")
      keys = Hibana.OTPCache.keys(name)
      assert :key1 in keys
      assert :key2 in keys
      assert length(keys) == 2
    end

    test "returns empty list for empty cache", %{name: name} do
      keys = Hibana.OTPCache.keys(name)
      assert keys == []
    end
  end
end
