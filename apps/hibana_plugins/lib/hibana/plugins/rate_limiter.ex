defmodule Hibana.Plugins.RateLimiter do
  @moduledoc """
  Rate limiting plugin using token bucket algorithm.

  ## Features

  - Token bucket algorithm for smooth rate limiting
  - Per-IP or custom key-based limiting
  - ETS-based storage for high performance
  - Automatic token refill after window expires
  - Configurable key extraction function

  ## Usage

      # Basic usage - 100 requests per minute per IP
      plug Hibana.Plugins.RateLimiter

      # Custom configuration
      plug Hibana.Plugins.RateLimiter,
        max_requests: 1000,
        window_ms: 60_000

      # Custom key function (e.g., by user ID from session)
      plug Hibana.Plugins.RateLimiter,
        max_requests: 100,
        window_ms: 60_000,
        key_fn: &custom_key/1

  ## Options

  - `:max_requests` - Maximum requests per window (default: `100`)
  - `:window_ms` - Time window in milliseconds (default: `60_000`)
  - `:storage` - Storage type (default: `:memory` with ETS)
  - `:key_fn` - Custom function to extract rate limit key (default: IP + path)

  ## Custom Key Function

  Example custom key function:

      def custom_key(conn) do
        conn.assigns.user_id || conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
      end

  ## Response

  When rate limit is exceeded, returns HTTP 429 with JSON body:

      %{
        "error" => "Rate limit exceeded",
        "retry_after" => 60000
      }

  ## ETS Table

  Uses `:rate_limiter` ETS table. Ensure it's created at startup:

      :ets.new(:rate_limiter, [:set, :named_table, :public])
  """

  use Hibana.Plugin
  import Plug.Conn

  defmodule State do
    defstruct [:key, :max_requests, :window_ms, :tokens, :last_refill]

    def new(key, max_requests, window_ms) do
      %__MODULE__{
        key: key,
        max_requests: max_requests,
        window_ms: window_ms,
        tokens: max_requests,
        last_refill: now_ms()
      }
    end

    defp now_ms, do: System.system_time(:millisecond)
  end

  @impl true
  def init(opts) do
    %{
      max_requests: Keyword.get(opts, :max_requests, 100),
      window_ms: Keyword.get(opts, :window_ms, 60_000),
      storage: Keyword.get(opts, :storage, :memory),
      key_fn: Keyword.get(opts, :key_fn, &extract_key/1)
    }
  end

  @doc "Start the rate limiter ETS table"
  def start_link do
    ensure_table_exists()
    {:ok, self()}
  end

  defp ensure_table_exists do
    case :ets.whereis(:rate_limiter) do
      :undefined ->
        :ets.new(:rate_limiter, [
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

  @impl true
  def call(conn, %{max_requests: max_requests, window_ms: window, key_fn: key_fn}) do
    key = key_fn.(conn)
    {allowed, _} = check_rate(key, max_requests, window)

    if allowed do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(429, Jason.encode!(%{error: "Rate limit exceeded", retry_after: window}))
      |> halt()
    end
  end

  defp extract_key(conn) do
    ip = conn.remote_ip |> Tuple.to_list() |> Enum.join(".")
    path = conn.path_info |> Enum.join("/")
    "#{ip}:#{path}"
  end

  defp check_rate(key, max_requests, window_ms) do
    ensure_table_exists()

    case :ets.lookup(:rate_limiter, key) do
      [{^key, _max, last_refill, tokens}] ->
        now = System.system_time(:millisecond)
        elapsed = now - last_refill

        if elapsed >= window_ms do
          new_tokens = max_requests - 1
          :ets.insert(:rate_limiter, {key, max_requests, now, new_tokens})
          {true, new_tokens}
        else
          if tokens > 0 do
            :ets.insert(:rate_limiter, {key, max_requests, last_refill, tokens - 1})
            {true, tokens - 1}
          else
            {false, 0}
          end
        end

      _ ->
        :ets.insert(
          :rate_limiter,
          {key, max_requests, System.system_time(:millisecond), max_requests - 1}
        )

        {true, max_requests - 1}
    end
  end
end
