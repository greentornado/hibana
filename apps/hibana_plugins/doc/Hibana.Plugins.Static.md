# `Hibana.Plugins.Static`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/static.ex#L1)

Static file serving plugin for serving files from disk.

## Features

- Serves files from configured directory
- Automatic content-type detection
- Cache control headers in production
- Gzip support (optional)
- Security: does not serve files outside root

## Usage

    # Serve from priv/static at root
    plug Hibana.Plugins.Static, at: "/", from: "priv/static"

    # Serve at /public prefix
    plug Hibana.Plugins.Static, at: "/public", from: "priv/static"

## Options

- `:at` - URL prefix to serve (default: `"/"`)
- `:from` - Directory to serve files from (default: `"priv/static"`)
- `:gzip` - Enable gzip support (default: `false`)
- `:cache_headers` - Add cache headers (default: `true`)

## Caching

In production (`MIX_ENV=prod`), adds cache headers:

    Cache-Control: public, max-age=3600

In development, no caching.

## Supported Content-Types

- HTML, CSS, JS, JSON
- Images (PNG, JPG, GIF, SVG, ICO)
- Fonts (WOFF, WOFF2, TTF, EOT)
- PDF, TXT, and binary files

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
