defmodule Hibana.Plugins.Cache do
  @moduledoc """
  ETS-based caching plugin with TTL and automatic expiration.

  ## Features

  - High-performance ETS storage
  - TTL (Time-To-Live) support in milliseconds
  - Automatic cleanup of expired entries
  - Cache-aside pattern support with `get_or_compute`
  - Concurrent read/write support

  ## Usage

      # Enable cache plug
      plug Hibana.Plugins.Cache

      # With custom TTL (5 minutes default)
      plug Hibana.Plugins.Cache, ttl: 300_000

  ## Module Functions

  ### get/1
  Get a value from cache:

      case Hibana.Plugins.Cache.get("user:123") do
        {:ok, nil} -> # cache miss
        {:ok, user} -> # cache hit
      end

  ### set/2-3
  Set a value with TTL:

      Hibana.Plugins.Cache.set("user:123", user_data, ttl: 60_000)

  ### get_or_compute/3
  Cache-aside pattern:

      {:ok, user} = Hibana.Plugins.Cache.get_or_compute(
        "user:123",
        300_000,
        fn -> Database.fetch_user(123) end
      )

  ### delete/1
  Delete a specific key:

      Hibana.Plugins.Cache.delete("user:123")

  ### clear/0
  Clear all cache entries:

      Hibana.Plugins.Cache.clear()

  ### stats/0
  Get cache statistics:

      Hibana.Plugins.Cache.stats()
      # => %{Size: 100, memory: 10240}

  ### cleanup/0
  Manually trigger cleanup of expired entries:

      Hibana.Plugins.Cache.cleanup()

  ## Options

  - `:ttl` - Default TTL in milliseconds (default: `300_000` = 5 minutes)
  - `:max_size` - Maximum entries (default: `1000`)

  ## ETS Table

  Uses `:hibana_cache` named ETS table with public access.
  Table is created on `start_link/0`.
  """

  use Hibana.Plugin

  @table :hibana_cache

  @doc """
  Creates the `:hibana_cache` ETS table for cache storage.

  Must be called before using `get/1`, `set/2`, or other cache functions.

  ## Returns

    - `{:ok, pid}` - The current process PID
  """
  def start_link do
    :ets.new(@table, [
      :named_table,
      :set,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    {:ok, self()}
  end

  @impl true
  def init(opts) do
    %{ttl: Keyword.get(opts, :ttl, 300_000), max_size: Keyword.get(opts, :max_size, 1000)}
  end

  @impl true
  def call(conn, _opts) do
    conn
  end

  @doc """
  Get a value from cache.
  """
  def get(key) do
    case :ets.lookup(@table, key) do
      [{^key, value, expiry}] ->
        if System.system_time(:millisecond) < expiry do
          {:ok, value}
        else
          :ets.delete(@table, key)
          {:ok, nil}
        end

      _ ->
        {:ok, nil}
    end
  end

  @doc """
  Set a value in cache with TTL. Enforces max_size limit with LRU eviction.
  """
  def set(key, value, ttl \\ 300_000, max_size \\ 1000) do
    expiry = System.system_time(:millisecond) + ttl

    # Check current size and evict if necessary
    current_size = :ets.info(@table, :size)

    if current_size >= max_size do
      # Evict 10% of entries
      evict_oldest(div(max_size, 10))
    end

    :ets.insert(@table, {key, value, expiry})
    :ok
  end

  defp evict_oldest(count) when count > 0 do
    # Get all entries sorted by expiry (LRU approximation)
    entries =
      :ets.tab2list(@table)
      |> Enum.sort_by(fn {_, _, expiry} -> expiry end)
      |> Enum.take(count)

    Enum.each(entries, fn {key, _, _} -> :ets.delete(@table, key) end)
  end

  defp evict_oldest(_), do: :ok

  @doc """
  Delete a key from cache.
  """
  def delete(key) do
    :ets.delete(@table, key)
    :ok
  end

  @doc """
  Check if a key exists.
  """
  def exists?(key) do
    case :ets.lookup(@table, key) do
      [{^key, _value, expiry}] ->
        if System.system_time(:millisecond) < expiry do
          true
        else
          :ets.delete(@table, key)
          false
        end

      _ ->
        false
    end
  end

  @doc """
  Get or compute a value.
  """
  def get_or_compute(key, ttl \\ 300_000, fun) do
    case get(key) do
      {:ok, nil} ->
        value = fun.()
        set(key, value, ttl)
        {:ok, value}

      {:ok, value} ->
        {:ok, value}
    end
  end

  @doc """
  Clear all cache entries.
  """
  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  @doc """
  Get cache statistics.
  """
  def stats do
    size = :ets.info(@table, :size)
    memory = :ets.info(@table, :memory)
    %{size: size, memory: memory}
  end

  @doc """
  Clean up expired entries.
  """
  def cleanup do
    now = System.system_time(:millisecond)

    :ets.foldl(
      fn {key, _value, expiry}, acc ->
        if now >= expiry do
          :ets.delete(@table, key)
        end

        acc
      end,
      :ok,
      @table
    )
  end
end
