# `Hibana.Plugins.RequestId`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/request_id.ex#L1)

Request ID and tracing plugin for debugging and log correlation.

## Features

- Generates unique request IDs for each request
- Uses existing X-Request-ID header if provided
- Adds request ID to response headers
- Available in conn.assigns for application use

## Usage

    # Basic usage
    plug Hibana.Plugins.RequestId

    # With custom header name
    plug Hibana.Plugins.RequestId, header: "x-correlation-id"

## Options

- `:header` - Request/response header name (default: `"x-request-id"`)
- `:generate_if_missing` - Generate ID if not provided (default: `true`)

## Conn Assignments

    conn.assigns.request_id  # => "a1b2c3d4e5f6g7h8"

## Response Header

Returns the request ID in the configured header:

    X-Request-ID: a1b2c3d4e5f6g7h8

## ID Format

16 bytes random data, hex-encoded (32 characters).

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
