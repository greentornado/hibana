# `Hibana.Plugins.CORS`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/cors.ex#L1)

CORS (Cross-Origin Resource Sharing) plugin for Hibana.

## Features

- Configurable allowed origins (including regex patterns)
- Automatic OPTIONS handling for preflight requests
- Support for credentials and max-age headers
- Configurable allowed methods and headers

## Usage

    # Basic usage (allow all origins)
    plug Hibana.Plugins.CORS

    # With custom configuration
    plug Hibana.Plugins.CORS,
      origins: ["https://example.com", "https://app.example.com"],
      headers: ["Content-Type", "Authorization", "X-Custom-Header"],
      credentials: true,
      max_age: 86400

    # With regex pattern for origins
    plug Hibana.Plugins.CORS,
      origins: ["^https://.*\.example\.com$"]

## Options

- `:origins` - List of allowed origins (default: `["*"]`)
- `:methods` - Allowed HTTP methods (default: standard methods)
- `:headers` - Allowed request headers (default: `["Content-Type", "Authorization"]`)
- `:credentials` - Allow credentials (default: `true`)
- `:max_age` - Preflight cache duration in seconds (default: `86400`)

## Response Headers

- `access-control-allow-origin` - The allowed origin
- `access-control-allow-methods` - Comma-separated allowed methods
- `access-control-allow-headers` - Comma-separated allowed headers
- `access-control-allow-credentials` - "true" if credentials allowed
- `access-control-max-age` - Preflight cache duration

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
