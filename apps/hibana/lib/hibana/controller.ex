defmodule Hibana.Controller do
  @moduledoc """
  Base controller module for handling HTTP responses in Hibana.

  Provides helper functions for sending JSON, HTML, plain text, redirects,
  and file downloads. Also includes session management and request inspection
  utilities.

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

  | Function | Content-Type | Description |
  |----------|-------------|-------------|
  | `json/2` | `application/json` | Send JSON response |
  | `html/2` | `text/html` | Send HTML response |
  | `text/2` | `text/plain` | Send plain text response |
  | `redirect/2` | n/a | 302 redirect to URL |
  | `send_file/3` | auto-detected | Send file as download |
  | `render/4` | `text/html` | Render a template via view module |

  ## Parameter Access

  - `conn.params` - Merged path and query parameters (e.g., `/users/:id`)
  - `conn.body_params` - Parsed request body as a map
  - `conn.query_params` - Query string parameters
  - `conn.req_headers` - List of `{header, value}` tuples

  ## Session Helpers

  - `get_session/2` - Retrieve a value from the session
  - `put_session/3` - Store a value in the session

  ## Status Code

  Set the status before sending a response:

      conn
      |> put_status(201)
      |> json(%{created: true})
  """

  import Plug.Conn

  defmacro __using__(_) do
    quote do
      import Plug.Conn, except: [put_status: 2]
      import Hibana.Controller
    end
  end

  @doc """
  Renders a template using the given view module and sends the result as HTML.

  ## Parameters

    - `conn` - The connection struct
    - `view` - A module that implements `render/2`
    - `template` - The template name passed to the view's `render/2`
    - `assigns` - A map of assigns passed to the template (default: `%{}`)

  ## Returns

  The connection with an HTML response.

  ## Examples

      ```elixir
      render(conn, MyApp.UserView, "index.html", %{users: users})
      ```
  """
  def render(conn, view, template, assigns \\ %{}) do
    content = apply(view, :render, [template, assigns])
    html(conn, content)
  end

  @doc """
  Sends a JSON response with `application/json` content type.

  Encodes the given data using `Jason.encode!/1` and sends it with
  the current status code (defaults to 200).

  ## Parameters

    - `conn` - The connection struct
    - `data` - Any term that can be encoded to JSON via `Jason.encode!/1`

  ## Returns

  The connection with the JSON response sent.

  ## Examples

      ```elixir
      json(conn, %{users: []})
      json(conn, %{message: "Created", id: 1})

      conn |> put_status(201) |> json(%{created: true})
      ```
  """
  def json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  @doc """
  Sends a plain text response with `text/plain` content type.

  ## Parameters

    - `conn` - The connection struct
    - `content` - The text string to send

  ## Returns

  The connection with the text response sent.

  ## Examples

      ```elixir
      text(conn, "Hello, World!")
      text(conn, "Not Found")
      ```
  """
  def text(conn, content) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(conn.status || 200, content)
  end

  @doc """
  Sends an HTML response with `text/html` content type.

  ## Parameters

    - `conn` - The connection struct
    - `content` - The HTML string to send

  ## Returns

  The connection with the HTML response sent.

  ## Examples

      ```elixir
      html(conn, "<h1>Hello!</h1>")
      html(conn, "<html><body>Welcome</body></html>")
      ```
  """
  def html(conn, content) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(conn.status || 200, content)
  end

  @doc """
  Redirects the client to the given URL with a 302 (Found) status.

  Sets the `location` response header and sends an empty body.

  ## Parameters

    - `conn` - The connection struct
    - `to:` - The target URL string

  ## Returns

  The connection with a 302 redirect response sent.

  ## Examples

      ```elixir
      redirect(conn, to: "/users")
      redirect(conn, to: "https://example.com")
      ```
  """
  def redirect(conn, to: url) do
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "")
  end

  @doc """
  Sends a file as a download response with `content-disposition: attachment`.

  Automatically detects the MIME type from the file extension. The filename
  and content type can be overridden via options.

  ## Parameters

    - `conn` - The connection struct
    - `path` - Absolute path to the file on disk
    - `opts` - Keyword list of options:
      - `:filename` - Override the download filename (default: basename of `path`)
      - `:content_type` - Override the MIME type (default: auto-detected)

  ## Returns

  The connection with the file response sent.

  ## Examples

      ```elixir
      send_file(conn, "/uploads/report.pdf")
      send_file(conn, "/data/export.csv", filename: "users.csv")
      send_file(conn, "/data/archive.bin", content_type: "application/zip")
      ```
  """
  def send_file(conn, path, opts \\ []) do
    filename = opts[:filename] || Path.basename(path)
    content_type = opts[:content_type] || mime_type(path)

    conn
    |> put_resp_content_type(content_type)
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> Plug.Conn.send_file(200, path)
  end

  defp mime_type(path) do
    case Path.extname(path) do
      ".html" -> "text/html"
      ".json" -> "application/json"
      ".txt" -> "text/plain"
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      ".pdf" -> "application/pdf"
      ".zip" -> "application/zip"
      _ -> "application/octet-stream"
    end
  end

  @doc """
  Sets the HTTP status code on the connection.

  The status is applied when a response helper (`json/2`, `text/2`, etc.) is
  called. If no status is set, response helpers default to 200.

  ## Parameters

    - `conn` - The connection struct
    - `status` - An integer HTTP status code (e.g., 201, 404, 500)

  ## Returns

  The updated connection with the status set.

  ## Examples

      ```elixir
      conn |> put_status(201) |> json(%{created: true})
      conn |> put_status(404) |> text("Not Found")
      ```
  """
  def put_status(conn, status) do
    %{conn | status: status}
  end

  @doc """
  Gets the current HTTP status code from the connection.

  ## Parameters

    - `conn` - The connection struct

  ## Returns

  The status code as an integer, or `nil` if not yet set.

  ## Examples

      ```elixir
      get_status(conn)
      # => 200
      ```
  """
  def get_status(conn), do: conn.status

  @doc """
  Gets the parsed body parameters from the connection.

  Requires a body parser (e.g., `Hibana.Plugins.BodyParser`) in the plug pipeline.

  ## Parameters

    - `conn` - The connection struct

  ## Returns

  A map of parsed body parameters.

  ## Examples

      ```elixir
      get_body_params(conn)
      # => %{"name" => "Alice", "email" => "alice@example.com"}
      ```
  """
  def get_body_params(conn), do: conn.body_params

  @doc """
  Gets the query string parameters from the connection.

  ## Parameters

    - `conn` - The connection struct

  ## Returns

  A map of query string parameters.

  ## Examples

      ```elixir
      # GET /users?page=2&limit=10
      get_query_params(conn)
      # => %{"page" => "2", "limit" => "10"}
      ```
  """
  def get_query_params(conn), do: conn.query_params

  @doc """
  Gets the first value of a request header by name (case-insensitive).

  ## Parameters

    - `conn` - The connection struct
    - `key` - The header name (case-insensitive)

  ## Returns

  The header value as a string, or `nil` if not present.

  ## Examples

      ```elixir
      req_header(conn, "content-type")
      # => "application/json"

      req_header(conn, "Authorization")
      # => "Bearer eyJhbGci..."
      ```
  """
  def req_header(conn, key), do: get_req_header(conn, String.downcase(key)) |> List.first()

  @doc """
  Gets a session value by key.

  Session data is stored in `conn.assigns.__session__` and managed by
  the `Hibana.Plugins.Session` plug.

  ## Parameters

    - `conn` - The connection struct
    - `key` - The session key (atom or string)

  ## Returns

  The session value, or `nil` if not found.

  ## Examples

      ```elixir
      get_session(conn, :user_id)
      # => 123
      ```
  """
  def get_session(conn, key) do
    session = Map.get(conn.assigns, :__session__, %{})
    Map.get(session, key)
  end

  @doc """
  Stores a value in the session under the given key.

  Session data is persisted to the client via the `Hibana.Plugins.Session` plug.

  ## Parameters

    - `conn` - The connection struct
    - `key` - The session key (atom or string)
    - `value` - The value to store

  ## Returns

  The updated connection with the session data modified.

  ## Examples

      ```elixir
      put_session(conn, :user_id, 123)
      put_session(conn, :flash, "Welcome back!")
      ```
  """
  def put_session(conn, key, value) do
    session = Map.get(conn.assigns, :__session__, %{})
    new_session = Map.put(session, key, value)
    assign(conn, :__session__, new_session)
  end

  @doc """
  Fetches and parses query parameters from the connection.

  Delegates to `Plug.Conn.fetch_query_params/2`. After calling this,
  `conn.query_params` will contain the parsed query string as a map.

  ## Parameters

    - `conn` - The connection struct
    - `opts` - Options passed to `Plug.Conn.fetch_query_params/2` (default: `[]`)

  ## Returns

  The connection with `query_params` populated.

  ## Examples

      ```elixir
      conn = fetch_query_params(conn)
      conn.query_params["page"]
      # => "2"
      ```
  """
  def fetch_query_params(conn, opts \\ []) do
    Plug.Conn.fetch_query_params(conn, opts)
  end

  @doc """
  Fetches and parses body parameters from the connection.

  This is a no-op passthrough. Use `Hibana.Plugins.BodyParser` in your plug
  pipeline for actual body parsing.

  ## Parameters

    - `conn` - The connection struct
    - `_parsers` - Unused (default: `[]`)

  ## Returns

  The connection unchanged.
  """
  def fetch_body_params(conn, _parsers \\ []) do
    conn
  end
end
