# `Hibana.Plugins.OTPCache`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/otp_cache.ex#L1)

OTP-based in-memory cache plugin.

This module delegates to `Hibana.OTPCache`.
See `Hibana.OTPCache` for full documentation.

## Usage

    # Start the cache
    Hibana.Plugins.OTPCache.start_link(name: :my_cache)

    # Set/Get values
    Hibana.Plugins.OTPCache.put(:my_cache, "key", "value", ttl: 60_000)
    Hibana.Plugins.OTPCache.get(:my_cache, "key")

## Options

Options are passed through to `Hibana.OTPCache.start_link/1`. See `Hibana.OTPCache` for the full list of supported options.

# `clear`

# `delete`

# `exists?`

# `get`

# `get_or_compute`

# `put`

# `start_link`

# `stats`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
