# `Hibana.Plugins.DistributedRateLimiter`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/distributed_rate_limiter.ex#L1)

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

# `before_send`

# `local_count_for`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
