# `Hibana.Plugins.BodyParser`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/body_parser.ex#L1)

Request body parser for JSON and form data.

## Features

- JSON parsing with configurable decoder
- URL-encoded form data parsing
- Automatic content-type detection
- Parsed data stored in `conn.body_params`

## Usage

    # Enable JSON and URL-encoded parsing (default)
    plug Hibana.Plugins.BodyParser

    # Custom configuration
    plug Hibana.Plugins.BodyParser,
      parsers: [:json, :urlencoded],
      json_decoder: Jason

## Options

- `:parsers` - List of enabled parsers (default: `[:json, :urlencoded]`)
- `:json_decoder` - JSON decoder module (default: `Jason`)

## Parsed Data

After parsing, the request body is available in:

    conn.body_params  # Map of parsed body data

Example:

    # POST body: {"name": "John", "email": "john@example.com"}
    conn.body_params["name"]  # => "John"

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
