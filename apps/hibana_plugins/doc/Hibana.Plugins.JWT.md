# `Hibana.Plugins.JWT`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/jwt.ex#L1)

JWT (JSON Web Token) authentication plugin.

## Features

- Token verification with configurable algorithms
- Automatic token expiration checking
- Claims extraction and assignment to conn
- Token generation utilities

## Usage

    # Basic usage
    plug Hibana.Plugins.JWT, secret: "my_secret_key"

    # With custom options
    plug Hibana.Plugins.JWT,
      secret: "my_secret_key",
      algorithm: :HS256,
      header_name: "authorization",
      scheme: "Bearer"

## Options

- `:secret` - Secret key for token verification (required)
- `:algorithm` - JWT algorithm (`:HS256`, `:HS384`, `:HS512`) (default: `:HS256`)
- `:claims` - Expected claims configuration (default: includes exp/iat)
- `:header_name` - Header to extract token from (default: `"authorization"`)
- `:scheme` - Auth scheme (default: `"Bearer"`)

## Conn Assignments

After successful verification, these assignments are made:

- `conn.assigns.jwt_claims` - Full JWT claims map
- `conn.assigns.current_user` - Value of "sub" claim

## Module Functions

### sign/2-3
Generate a new JWT token:

    claims = %{"sub" => "user123", "name" => "John"}
    token = Hibana.Plugins.JWT.sign(claims, "secret", exp: 3600)

### verify/2-3
Verify and decode a token:

    {:ok, claims} = Hibana.Plugins.JWT.verify(token, "secret")

### decode/1
Decode without verification (for debugging):

    {:ok, claims} = Hibana.Plugins.JWT.decode(token)

# `before_send`

# `decode`

Extract claims from a token without verification (for debugging).

# `sign`

Generate a new JWT token.

# `start_link`

# `verify`

Verify and decode a JWT token.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
