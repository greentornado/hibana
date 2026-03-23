defmodule Hibana.OTPCache do
  @moduledoc """
  OTP-based in-memory cache using GenServer with TTL support.

  ## Features

  - Key-value storage with automatic expiration
  - TTL (Time-To-Live) support in milliseconds
  - Eviction when max size is reached
  - Automatic cleanup of expired entries
  - `get_or_compute` for cache-aside pattern

  ## Usage

      # Start the cache
      Hibana.OTPCache.start_link(name: :my_cache)

      # Set a value with TTL (60 seconds)
      Hibana.OTPCache.put(:my_cache, "user:1", user_data, ttl: 60_000)

      # Get a value
      Hibana.OTPCache.get(:my_cache, "user:1")

      # Get or compute (lazy loading)
      Hibana.OTPCache.get_or_compute(
        :my_cache,
        "user:1",
        fn -> fetch_user_from_db(1) end,
        ttl: 300_000
      )

      # Check if key exists
      Hibana.OTPCache.exists?(:my_cache, "user:1")

      # Delete a key
      Hibana.OTPCache.delete(:my_cache, "user:1")

      # Get cache statistics
      Hibana.OTPCache.stats(:my_cache)

      # Clear all entries
      Hibana.OTPCache.clear(:my_cache)

  ## Options

  - `:name` - The server name (default: `__MODULE__`)
  - `:max_size` - Maximum number of entries (default: 1000)

  ## Supervision Integration

      children = [
        {Hibana.OTPCache, name: :my_cache, max_size: 5000}
      ]
  """

  use GenServer

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    max_size = Keyword.get(opts, :max_size, 1000)
    GenServer.start_link(__MODULE__, %{max_size: max_size, cache: %{}}, name: name)
  end

  def init(state) do
    schedule_cleanup()
    {:ok, state}
  end

  @doc """
  Put a value into cache with optional TTL (in milliseconds).
  """
  def put(server \\ __MODULE__, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl)
    expiry = if ttl, do: System.system_time(:millisecond) + ttl, else: nil

    GenServer.call(server, {:put, key, value, expiry})
  end

  @doc """
  Get a value from cache.
  """
  def get(server \\ __MODULE__, key) do
    GenServer.call(server, {:get, key})
  end

  @doc """
  Get a value or compute if not exists.
  """
  def get_or_compute(server \\ __MODULE__, key, compute_fn, opts \\ []) do
    ttl = Keyword.get(opts, :ttl, 300_000)

    case get(server, key) do
      nil ->
        value = compute_fn.()
        put(server, key, value, ttl: ttl)
        {:ok, value}

      value ->
        {:ok, value}
    end
  end

  @doc """
  Delete a key from cache.
  """
  def delete(server \\ __MODULE__, key) do
    GenServer.call(server, {:delete, key})
  end

  @doc """
  Check if key exists and is not expired.
  """
  def exists?(server \\ __MODULE__, key) do
    GenServer.call(server, {:exists, key})
  end

  @doc """
  Clear all cache entries.
  """
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  @doc """
  Get cache statistics.
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Get all keys.
  """
  def keys(server \\ __MODULE__) do
    GenServer.call(server, :keys)
  end

  def handle_call({:put, key, value, expiry}, _from, %{cache: cache, max_size: max_size} = state) do
    new_cache =
      if map_size(cache) >= max_size do
        # Evict oldest
        {_, new_cache} = Map.pop(cache, hd(Map.keys(cache)))
        Map.put(new_cache, key, {value, expiry})
      else
        Map.put(cache, key, {value, expiry})
      end

    {:reply, :ok, %{state | cache: new_cache}}
  end

  def handle_call({:get, key}, _from, %{cache: cache} = state) do
    case Map.get(cache, key) do
      nil ->
        {:reply, nil, state}

      {v, nil} ->
        {:reply, v, state}

      {v, expiry} ->
        if System.system_time(:millisecond) > expiry do
          # Remove expired entry
          {:reply, nil, %{state | cache: Map.delete(cache, key)}}
        else
          {:reply, v, state}
        end
    end
  end

  def handle_call({:delete, key}, _from, %{cache: cache} = state) do
    new_cache = Map.delete(cache, key)
    {:reply, :ok, %{state | cache: new_cache}}
  end

  def handle_call({:exists, key}, _from, %{cache: cache} = state) do
    exists =
      case Map.get(cache, key) do
        nil -> false
        {_, nil} -> true
        {_, expiry} -> !expiry || System.system_time(:millisecond) < expiry
      end

    {:reply, exists, state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | cache: %{}}}
  end

  def handle_call(:stats, _from, %{cache: cache} = state) do
    now = System.system_time(:millisecond)

    valid =
      Enum.count(cache, fn
        {_, {_, nil}} -> true
        {_, {_, expiry}} -> expiry > now
      end)

    {:reply, %{total: map_size(cache), valid: valid, max_size: state.max_size}, state}
  end

  def handle_call(:keys, _from, %{cache: cache} = state) do
    {:reply, Map.keys(cache), state}
  end

  def handle_info(:cleanup, %{cache: cache} = state) do
    now = System.system_time(:millisecond)

    new_cache =
      Enum.reduce(cache, %{}, fn
        {k, {v, nil}}, acc -> Map.put(acc, k, {v, nil})
        {k, {v, expiry}}, acc when expiry > now -> Map.put(acc, k, {v, expiry})
        _, acc -> acc
      end)

    schedule_cleanup()
    {:noreply, %{state | cache: new_cache}}
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup, 60_000)
  end
end
