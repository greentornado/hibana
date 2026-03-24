# `Hibana.Plugins.APIVersioning`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/api_versioning.ex#L1)

API Versioning plugin for versioned REST APIs.

## Features

- Multiple versioning strategies (path, header, query)
- Configurable default version
- Available in conn.assigns
- Validates against known versions

## Usage

    # Path-based versioning (default)
    plug Hibana.Plugins.APIVersioning

    # Multiple strategies
    plug Hibana.Plugins.APIVersioning,
      default: "v1",
      strategies: [:path, :header, :query]

## Versioning Strategies

### Path Strategy (default)
Version in URL path:

    GET /api/v1/users
    GET /api/v2/users

### Header Strategy
Version via Accept header:

    Accept: application/vnd.elixir-web.v1+json
    Accept: application/vnd.elixir-web.v2+json

### Query Strategy
Version via query parameter:

    GET /api/users?version=v1

## Options

- `:default` - Default API version (default: `"v1"`)
- `:strategies` - List of strategies to use (default: `[:path]`)
- `:versions` - List of valid versions (default: `["v1", "v2"]`)

## Conn Assignments

After version extraction:

    conn.assigns.api_version  # => "v2"

## Module Function

### get_version/1
Get the current API version from connection:

    version = Hibana.Plugins.APIVersioning.get_version(conn)

# `before_send`

# `get_version`

Get the current API version from connection.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
