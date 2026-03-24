# `Hibana.Plugins.Auth`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/auth.ex#L1)

HTTP Basic authentication plugin.

## Features

- RFC 7617 compliant Basic Auth
- Customizable realm name
- Pluggable validator function
- Automatic 401 response with WWW-Authenticate header

## Usage

    # Basic usage with default realm
    plug Hibana.Plugins.Auth

    # With custom realm
    plug Hibana.Plugins.Auth, realm: "Admin Area"

    # With custom validator
    plug Hibana.Plugins.Auth,
      validator: fn username, password ->
        username == "admin" && password == "secret"
      end

## Options

- `:realm` - Authentication realm name (default: `"Restricted"`)
- `:validator` - Custom validation function (default: always returns `false`)

## Validator Function

The validator receives username and password:

    validator = fn username, password ->
      # Check against database, LDAP, etc.
      username == "admin" && password == "secret"
    end

## Conn Assignments

On successful authentication:

    conn.assigns.current_user  # => "username"

## Response

On failed authentication:

    HTTP 401 Unauthorized
    WWW-Authenticate: Basic realm="Protected Area"

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
