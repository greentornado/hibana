# `Hibana.Plugins.Cache`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/cache.ex#L1)

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

# `before_send`

# `cleanup`

Clean up expired entries.

# `clear`

Clear all cache entries.

# `delete`

Delete a key from cache.

# `exists?`

Check if a key exists.

# `get`

Get a value from cache.

# `get_or_compute`

Get or compute a value.

# `set`

Set a value in cache with TTL.

# `start_link`

# `start_link`

# `stats`

Get cache statistics.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
