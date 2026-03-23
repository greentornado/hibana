defmodule Hibana.Plugins.DistributedRateLimiter do
  @moduledoc """
  Distributed rate limiter that works across cluster nodes.
  Uses the Cluster module for cross-node counter synchronization.

  ## Usage

      plug Hibana.Plugins.DistributedRateLimiter,
        max_requests: 1000,
        window_ms: 60_000,
        sync_interval: 5_000

  ## Options

  - `:max_requests` - Maximum number of requests allowed within the time window (default: `1000`)
  - `:window_ms` - Time window in milliseconds for rate limiting (default: `60_000`)
  - `:key_fn` - A function `(Plug.Conn.t() -> String.t())` that returns a rate-limiting key for the request; defaults to client IP address
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    ensure_table_exists()

    %{
      max_requests: Keyword.get(opts, :max_requests, 1000),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      key_fn: Keyword.get(opts, :key_fn, &default_key/1)
    }
  end

  @impl true
  def call(conn, %{max_requests: max, window_ms: window, key_fn: key_fn}) do
    key = key_fn.(conn)

    # Get local count
    local_count = get_local_count(key, window)

    # Get remote counts from other nodes (best-effort, non-blocking)
    remote_count = get_remote_counts(key, window)

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
    cutoff = now - window

    case :ets.lookup(:distributed_rate_limiter, key) do
      [{^key, timestamps}] ->
        valid = Enum.filter(timestamps, &(&1 > cutoff))
        :ets.insert(:distributed_rate_limiter, {key, valid})
        length(valid)

      _ ->
        0
    end
  end

  defp increment_count(key) do
    now = System.system_time(:millisecond)

    case :ets.lookup(:distributed_rate_limiter, key) do
      [{^key, timestamps}] ->
        :ets.insert(:distributed_rate_limiter, {key, [now | timestamps]})

      _ ->
        :ets.insert(:distributed_rate_limiter, {key, [now]})
    end
  end

  defp get_remote_counts(key, window) do
    Node.list()
    |> Enum.map(fn node ->
      try do
        :rpc.call(node, __MODULE__, :local_count_for, [key, window], 1_000)
      catch
        _, _ -> 0
      end
    end)
    |> Enum.sum()
  end

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
end
