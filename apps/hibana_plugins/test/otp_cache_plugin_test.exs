defmodule Hibana.Plugins.OTPCacheTest do
  use ExUnit.Case, async: false

  defp unique_name do
    :"otp_cache_test_#{System.unique_integer([:positive, :monotonic])}"
  end

  setup do
    name = unique_name()
    {:ok, pid} = Hibana.Plugins.OTPCache.start_link(name: name)
    %{cache: pid, name: name}
  end

  describe "start_link/1" do
    test "starts with custom name" do
      name = unique_name()
      {:ok, pid} = Hibana.Plugins.OTPCache.start_link(name: name)
      assert is_pid(pid)
    end

    test "starts with max_size option" do
      name = unique_name()
      {:ok, pid} = Hibana.Plugins.OTPCache.start_link(name: name, max_size: 500)
      assert is_pid(pid)
    end
  end

  describe "put/4" do
    test "stores value with key", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key, "value")
      assert Hibana.Plugins.OTPCache.get(name, :key) == "value"
    end

    test "stores value with TTL", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :ttl_key, "value", ttl: 5000)
      assert Hibana.Plugins.OTPCache.get(name, :ttl_key) == "value"
    end

    test "overwrites existing value", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key, "value1")
      Hibana.Plugins.OTPCache.put(name, :key, "value2")
      assert Hibana.Plugins.OTPCache.get(name, :key) == "value2"
    end

    test "respects max_size by evicting oldest" do
      name = unique_name()
      Hibana.Plugins.OTPCache.start_link(name: name, max_size: 2)
      Hibana.Plugins.OTPCache.put(name, :key1, "value1")
      Hibana.Plugins.OTPCache.put(name, :key2, "value2")
      Hibana.Plugins.OTPCache.put(name, :key3, "value3")
      assert Hibana.Plugins.OTPCache.get(name, :key1) == nil
      assert Hibana.Plugins.OTPCache.get(name, :key2) == "value2"
      assert Hibana.Plugins.OTPCache.get(name, :key3) == "value3"
    end
  end

  describe "get/2" do
    test "returns nil for missing key", %{name: name} do
      assert Hibana.Plugins.OTPCache.get(name, :missing) == nil
    end

    test "returns value for existing key", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key1, "value1")
      assert Hibana.Plugins.OTPCache.get(name, :key1) == "value1"
    end

    test "returns nil for expired key", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :expired, "value", ttl: 10)
      Process.sleep(50)
      assert Hibana.Plugins.OTPCache.get(name, :expired) == nil
    end
  end

  describe "get_or_compute/4" do
    test "returns existing value without computing", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key, "cached")

      {:ok, result} =
        Hibana.Plugins.OTPCache.get_or_compute(name, :key, fn ->
          "computed"
        end)

      assert result == "cached"
    end

    test "computes and stores when missing", %{name: name} do
      {:ok, result} =
        Hibana.Plugins.OTPCache.get_or_compute(name, :missing, fn ->
          "computed_value"
        end)

      assert result == "computed_value"
    end
  end

  describe "delete/2" do
    test "removes key from cache", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key, "value")
      :ok = Hibana.Plugins.OTPCache.delete(name, :key)
      assert Hibana.Plugins.OTPCache.get(name, :key) == nil
    end
  end

  describe "exists?/2" do
    test "returns true for existing key", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key, "value")
      assert Hibana.Plugins.OTPCache.exists?(name, :key) == true
    end

    test "returns false for missing key", %{name: name} do
      assert Hibana.Plugins.OTPCache.exists?(name, :missing) == false
    end

    test "returns false for expired key", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :expired, "value", ttl: 10)
      Process.sleep(50)
      assert Hibana.Plugins.OTPCache.exists?(name, :expired) == false
    end
  end

  describe "clear/1" do
    test "removes all entries", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key1, "value1")
      Hibana.Plugins.OTPCache.put(name, :key2, "value2")
      :ok = Hibana.Plugins.OTPCache.clear(name)
      assert Hibana.Plugins.OTPCache.get(name, :key1) == nil
    end
  end

  describe "stats/1" do
    test "returns cache statistics", %{name: name} do
      Hibana.Plugins.OTPCache.put(name, :key1, "value1")
      Hibana.Plugins.OTPCache.put(name, :key2, "value2")
      stats = Hibana.Plugins.OTPCache.stats(name)
      assert stats.total == 2
      assert stats.valid == 2
    end
  end
end
