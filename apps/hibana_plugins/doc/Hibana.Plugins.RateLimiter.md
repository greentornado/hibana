# `Hibana.Plugins.RateLimiter`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/rate_limiter.ex#L1)

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

# `before_send`

# `start_link`

Start the rate limiter ETS table

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
