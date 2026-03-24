# `Hibana.Plugins.Compression`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/compression.ex#L1)

Response compression plugin supporting gzip and deflate.

## Usage

    plug Hibana.Plugins.Compression
    plug Hibana.Plugins.Compression, level: 6, min_size: 1024

## Options

- `:level` - Compression level from 0 (no compression) to 9 (maximum compression), used for deflate encoding (default: `6`)
- `:min_size` - Minimum response body size in bytes before compression is applied (default: `860`)

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
