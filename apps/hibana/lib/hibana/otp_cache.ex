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

  @doc """
  Starts the OTP cache GenServer.

  ## Parameters

    - `opts` - Keyword list of options:
      - `:name` - The server name (default: `Hibana.OTPCache`)
      - `:max_size` - Maximum number of entries before eviction (default: `1000`)

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      {:ok, _pid} = Hibana.OTPCache.start_link(name: :my_cache, max_size: 5000)
      ```
  """
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
  Puts a value into the cache with an optional TTL (time-to-live).

  If the cache has reached `max_size`, the oldest entry is evicted.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)
    - `key` - The cache key (any term)
    - `value` - The value to store
    - `opts` - Options:
      - `:ttl` - Time-to-live in milliseconds; `nil` means no expiry

  ## Returns

  `:ok`

  ## Examples

      ```elixir
      Hibana.OTPCache.put(:my_cache, "user:1", user_data, ttl: 60_000)
      Hibana.OTPCache.put(:my_cache, "config", config)
      ```
  """
  def put(server \\ __MODULE__, key, value, opts \\ []) do
    ttl = Keyword.get(opts, :ttl)
    expiry = if ttl, do: System.system_time(:millisecond) + ttl, else: nil

    GenServer.call(server, {:put, key, value, expiry})
  end

  @doc """
  Gets a value from the cache by key.

  Returns `nil` if the key is not found or has expired (expired entries
  are automatically removed on access).

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)
    - `key` - The cache key

  ## Returns

  The cached value, or `nil` if not found or expired.

  ## Examples

      ```elixir
      Hibana.OTPCache.get(:my_cache, "user:1")
      # => %{name: "Alice"}

      Hibana.OTPCache.get(:my_cache, "missing")
      # => nil
      ```
  """
  def get(server \\ __MODULE__, key) do
    GenServer.call(server, {:get, key})
  end

  @doc """
  Gets a cached value or computes and caches it if not present.

  Implements the cache-aside (lazy-loading) pattern. If the key exists
  and is not expired, returns the cached value. Otherwise, calls
  `compute_fn`, stores the result with the given TTL, and returns it.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)
    - `key` - The cache key
    - `compute_fn` - A zero-arity function to compute the value on cache miss
    - `opts` - Options:
      - `:ttl` - Time-to-live in milliseconds (default: `300_000`)

  ## Returns

    - `{:ok, value}` - The cached or computed value

  ## Examples

      ```elixir
      {:ok, user} = Hibana.OTPCache.get_or_compute(:my_cache, "user:1", fn ->
        Repo.get!(User, 1)
      end, ttl: 300_000)
      ```
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
  Deletes a key from the cache.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)
    - `key` - The cache key to delete

  ## Returns

  `:ok`
  """
  def delete(server \\ __MODULE__, key) do
    GenServer.call(server, {:delete, key})
  end

  @doc """
  Checks if a key exists in the cache and is not expired.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)
    - `key` - The cache key

  ## Returns

  `true` if the key exists and has not expired, `false` otherwise.
  """
  def exists?(server \\ __MODULE__, key) do
    GenServer.call(server, {:exists, key})
  end

  @doc """
  Clears all entries from the cache.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)

  ## Returns

  `:ok`
  """
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  @doc """
  Gets cache statistics including total entries, valid (non-expired) entries,
  and maximum size.

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)

  ## Returns

  A map with `:total`, `:valid`, and `:max_size` keys.

  ## Examples

      ```elixir
      Hibana.OTPCache.stats(:my_cache)
      # => %{total: 150, valid: 142, max_size: 1000}
      ```
  """
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc """
  Gets all keys currently in the cache (including expired ones not yet cleaned up).

  ## Parameters

    - `server` - The cache server name (default: `Hibana.OTPCache`)

  ## Returns

  A list of cache keys.
  """
  def keys(server \\ __MODULE__) do
    GenServer.call(server, :keys)
  end

  def handle_call({:put, key, value, expiry}, _from, %{cache: cache, max_size: max_size} = state) do
    new_cache =
      if map_size(cache) >= max_size and not Map.has_key?(cache, key) do
        # Evict entry with earliest expiry, or first inserted if all are nil-expiry
        evict_key =
          cache
          |> Enum.min_by(fn
            {_k, {_v, nil}} -> :infinity
            {_k, {_v, exp}} -> exp
          end)
          |> elem(0)

        {_, trimmed} = Map.pop(cache, evict_key)
        Map.put(trimmed, key, {value, expiry})
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
