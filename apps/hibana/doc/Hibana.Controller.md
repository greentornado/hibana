# `Hibana.Controller`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/controller.ex#L1)

Base controller module for handling HTTP responses.

## Usage

    defmodule MyApp.UserController do
      use Hibana.Controller

      def index(conn) do
        json(conn, %{users: []})
      end

      def show(conn) do
        id = conn.params["id"]
        json(conn, %{user: %{id: id, name: "User"}})
      end
    end

## Response Helpers

### json/1
Sends a JSON response with `application/json` content type.

    json(conn, %{message: "Hello!"})

### html/1
Sends an HTML response with `text/html` content type.

    html(conn, "<h1>Hello!</h1>")

### text/1
Sends a plain text response with `text/plain` content type.

    text(conn, "Hello, World!")

### redirect/1
Redirects to another URL.

    redirect(conn, to: "/users")

### send_file/2
Sends a file as a download.

    send_file(conn, "/path/to/file.pdf")

## Parameter Access

- `conn.params` - Path parameters (e.g., `/users/:id`)
- `conn.body_params` - Request body as a map
- `conn.query_params` - Query string parameters
- `conn.req_headers` - Request headers

## Session Helpers

- `get_session(conn, key)` - Get session value
- `put_session(conn, key, value)` - Set session value

# `fetch_body_params`

Fetch and parse body parameters from the connection.

# `fetch_query_params`

Fetch and parse query parameters from the connection.

# `get_body_params`

Get the parsed body parameters from the connection.

# `get_query_params`

Get the query string parameters from the connection.

# `get_session`

Get a session value by key.

# `get_status`

Get the current HTTP status code from the connection.

# `html`

Send an HTML response.

# `json`

Send a JSON response with the given data.

# `put_session`

Store a value in the session under the given key.

# `put_status`

Set the HTTP status code on the connection.

# `redirect`

Redirect to the given URL with a 302 status.

# `render`

Render a template using the given view module and send as HTML.

# `req_header`

Get the first value of a request header by name (case-insensitive).

# `send_file`

Send a file as a download response with optional filename and content type.

# `text`

Send a plain text response.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
