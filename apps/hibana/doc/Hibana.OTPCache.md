# `Hibana.OTPCache`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/otp_cache.ex#L1)

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

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

Clear all cache entries.

# `delete`

Delete a key from cache.

# `exists?`

Check if key exists and is not expired.

# `get`

Get a value from cache.

# `get_or_compute`

Get a value or compute if not exists.

# `init`

# `keys`

Get all keys.

# `put`

Put a value into cache with optional TTL (in milliseconds).

# `start_link`

# `stats`

Get cache statistics.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
