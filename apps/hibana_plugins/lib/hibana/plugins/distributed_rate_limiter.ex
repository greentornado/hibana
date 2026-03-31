defmodule Hibana.Plugins.DistributedRateLimiter do
  @moduledoc """
  Distributed rate limiter that works across cluster nodes.
  Uses efficient sampling and caching to minimize cross-node RPC overhead.

  ## Usage

      plug Hibana.Plugins.DistributedRateLimiter,
        max_requests: 1000,
        window_ms: 60_000

  ## Options

  - `:max_requests` - Maximum number of requests allowed within the time window (default: `1000`)
  - `:window_ms` - Time window in milliseconds for rate limiting (default: `60_000`)
  - `:key_fn` - A function `(Plug.Conn.t() -> String.t())` that returns a rate-limiting key for the request; defaults to client IP address
  - `:sample_size` - Number of nodes to sample for distributed count (default: `3`)

  ## Performance Notes

  This plugin uses an efficient sampling strategy:
  - Queries only a sample of nodes (not all nodes) to reduce RPC overhead
  - Caches remote counts for 1 second to avoid repeated RPCs
  - Falls back to local-only counting if cluster is unavailable

  In a 10-node cluster, this reduces RPC calls from 10 per request to ~3 per request.
  """

  use Hibana.Plugin
  import Plug.Conn

  # Cache TTL for remote counts in milliseconds
  @remote_cache_ttl 1000

  @impl true
  def init(opts) do
    ensure_table_exists()
    ensure_cache_table_exists()

    %{
      max_requests: Keyword.get(opts, :max_requests, 1000),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      key_fn: Keyword.get(opts, :key_fn, &default_key/1),
      sample_size: Keyword.get(opts, :sample_size, 3)
    }
  end

  @impl true
  def call(conn, %{max_requests: max, window_ms: window, key_fn: key_fn, sample_size: sample_size}) do
    key = key_fn.(conn)

    # Get local count
    local_count = get_local_count(key, window)

    # Get remote counts from sampled nodes (efficient, not all nodes)
    remote_count = get_remote_counts_cached(key, window, sample_size)

    total = local_count + remote_count

    if total < max do
      increment_count(key)

      conn
      |> put_resp_header("x-ratelimit-limit", to_string(max))
      |> put_resp_header("x-ratelimit-remaining", to_string(max(max - total - 1, 0)))
    else
      conn
      |> put_resp_content_type("application/json")
      |> put_resp_header("x-ratelimit-limit", to_string(max))
      |> put_resp_header("x-ratelimit-remaining", "0")
      |> put_resp_header("retry-after", to_string(div(window, 1000)))
      |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded"}))
      |> halt()
    end
  end

  defp default_key(conn) do
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    "distributed_rate:#{ip}"
  end

  defp get_local_count(key, window) do
    now = System.system_time(:millisecond)

    case :ets.lookup(:distributed_rate_limiter, key) do
      [{^key, count, window_start}] when now - window_start < window ->
        count

      [{^key, _count, _window_start}] ->
        # Window expired, reset
        :ets.insert(:distributed_rate_limiter, {key, 0, now})
        0

      _ ->
        0
    end
  end

  defp increment_count(key) do
    now = System.system_time(:millisecond)

    case :ets.lookup(:distributed_rate_limiter, key) do
      [{^key, _count, _window_start}] ->
        :ets.update_counter(:distributed_rate_limiter, key, {2, 1})

      _ ->
        :ets.insert(:distributed_rate_limiter, {key, 1, now})
    end
  end

  defp get_remote_counts_cached(key, window, sample_size) do
    now = System.system_time(:millisecond)
    cache_key = {key, window}

    # Check cache first
    case :ets.lookup(:distributed_rate_limiter_cache, cache_key) do
      [{^cache_key, count, timestamp}] when now - timestamp < @remote_cache_ttl ->
        # Cache hit, use cached value
        count

      _ ->
        # Cache miss or expired, fetch fresh data
        count = get_remote_counts_sampled(key, window, sample_size)
        :ets.insert(:distributed_rate_limiter_cache, {cache_key, count, now})
        count
    end
  end

  defp get_remote_counts_sampled(key, window, sample_size) do
    nodes = Node.list()

    if length(nodes) == 0 do
      # No remote nodes, count is 0
      0
    else
      # Sample a subset of nodes to reduce RPC overhead
      # Use consistent hashing based on key to select same nodes for same key
      sampled_nodes = sample_nodes(nodes, key, sample_size)

      # Query sampled nodes in parallel with short timeout
      tasks =
        Enum.map(sampled_nodes, fn node ->
          Task.async(fn ->
            try do
              :rpc.call(node, __MODULE__, :local_count_for, [key, window], 200)
            catch
              _, _ -> 0
            end
          end)
        end)

      # Collect results with shorter timeout (300ms max)
      results =
        Enum.map(tasks, fn task ->
          try do
            Task.await(task, 300)
          catch
            _ -> 0
          end
        end)

      # Calculate estimated total based on sample
      # If we sample 3 out of 10 nodes, multiply by 10/3 to estimate total
      sampled_count = Enum.sum(results)

      if length(sampled_nodes) < length(nodes) do
        # Extrapolate from sample to estimate total
        # This is an approximation but sufficient for rate limiting
        scale_factor = length(nodes) / length(sampled_nodes)
        trunc(sampled_count * scale_factor)
      else
        sampled_count
      end
    end
  end

  defp sample_nodes(nodes, key, sample_size) do
    # Use consistent hashing to deterministically select same nodes for same key
    # This ensures the same key always queries the same subset of nodes
    node_count = length(nodes)

    if node_count <= sample_size do
      nodes
    else
      # Hash the key to get a starting index
      hash = :erlang.phash2(key)
      start_index = rem(hash, node_count)

      # Select sample_size nodes starting from start_index
      indexed_nodes = Enum.with_index(nodes)

      # Rotate list so start_index is first
      {before_start, from_start} = Enum.split(indexed_nodes, start_index)
      rotated = from_start ++ before_start

      # Take first sample_size nodes
      rotated
      |> Enum.take(sample_size)
      |> Enum.map(fn {node, _idx} -> node end)
    end
  end

  @doc """
  Returns the local request count for a key within the given time window.

  Called via RPC from other cluster nodes to aggregate distributed counts.

  ## Parameters

    - `key` - The rate-limiting key
    - `window` - The time window in milliseconds

  ## Returns

  An integer count of requests from this node.
  """
  def local_count_for(key, window) do
    get_local_count(key, window)
  end

  defp ensure_table_exists do
    case :ets.whereis(:distributed_rate_limiter) do
      :undefined ->
        :ets.new(:distributed_rate_limiter, [
          :named_table,
          :set,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end
  end

  defp ensure_cache_table_exists do
    case :ets.whereis(:distributed_rate_limiter_cache) do
      :undefined ->
        :ets.new(:distributed_rate_limiter_cache, [
          :named_table,
          :set,
          :public,
          read_concurrency: true,
          write_concurrency: true
        ])

      _ ->
        :ok
    end
  end
end
