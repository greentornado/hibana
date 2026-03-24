# `Hibana.Plugins.ContentNegotiation`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/content_negotiation.ex#L1)

Content Negotiation plugin for format selection (JSON/XML/CSV/etc).

## Features

- Automatic format selection based on Accept header
- Supports JSON, XML, HTML, Text, CSV formats
- Custom format renderer via `render_as/3`
- Falls back to default format if none matches

## Usage

    # Enable with JSON only (default)
    plug Hibana.Plugins.ContentNegotiation

    # Multiple formats
    plug Hibana.Plugins.ContentNegotiation,
      formats: ["json", "xml", "html"],
      default: "json"

## Options

- `:formats` - Supported formats (default: `["json"]`)
- `:default` - Default format (default: `"json"`)

## Supported Formats

| Format | Content-Type |
|--------|--------------|
| json   | application/json |
| xml    | application/xml |
| html   | text/html |
| text   | text/plain |
| csv    | text/csv |

## Conn Assignments

After negotiation:

    conn.assigns.response_format       # => "json"
    conn.assigns.response_content_type   # => "application/json"

## Rendering Responses

Use `render_as/3` to render in the negotiated format:

    defmodule MyController do
      use Hibana.Controller

      def index(conn) do
        data = %{users: [...]}
        format = conn.assigns.response_format || "json"
        render_as(conn, format, data)
      end
    end

# `before_send`

# `render_as`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
