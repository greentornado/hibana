# `Hibana.Plugins.RequestSigning`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/request_signing.ex#L1)

HMAC request signing plugin for API-to-API authentication.

## As a Plug (verify incoming requests)

    plug Hibana.Plugins.RequestSigning,
      secret: "my-shared-secret",
      max_age: 300

## Signing outgoing requests

    headers = Hibana.Plugins.RequestSigning.sign_headers(
      method: "POST",
      path: "/api/data",
      body: ~s({"key":"value"}),
      secret: "my-shared-secret"
    )

## Options

- `:secret` - Shared secret key used for HMAC signing (required)
- `:max_age` - Maximum allowed age of a request signature in seconds (default: `300`)
- `:algorithm` - Hash algorithm for HMAC computation (default: `:sha256`)

# `sign`

Sign request parameters and return the signature string.

## Options
  - `:method` - HTTP method (required)
  - `:path` - request path (required)
  - `:body` - request body (default: "")
  - `:secret` - shared secret (required)
  - `:timestamp` - override timestamp (default: current time)
  - `:algorithm` - hash algorithm (default: :sha256)

# `sign_headers`

Generate signature headers for an outgoing request.
Returns a list of `{header_name, value}` tuples.

## Options
  - `:method` - HTTP method (required)
  - `:path` - request path (required)
  - `:body` - request body (default: "")
  - `:secret` - shared secret (required)
  - `:timestamp` - override timestamp (default: current time)
  - `:algorithm` - hash algorithm (default: :sha256)

# `verify_signature`

Verify a signature against request parameters.

Returns `:ok` or `{:error, reason}`.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
