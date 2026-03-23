defmodule Hibana.Controller do
  @moduledoc """
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
  """

  import Plug.Conn

  defmacro __using__(_) do
    quote do
      import Plug.Conn, except: [put_status: 2]
      import Hibana.Controller
    end
  end

  @doc "Render a template using the given view module and send as HTML."
  def render(conn, view, template, assigns \\ %{}) do
    content = apply(view, :render, [template, assigns])
    html(conn, content)
  end

  @doc "Send a JSON response with the given data."
  def json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(conn.status || 200, Jason.encode!(data))
  end

  @doc "Send a plain text response."
  def text(conn, content) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(conn.status || 200, content)
  end

  @doc "Send an HTML response."
  def html(conn, content) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(conn.status || 200, content)
  end

  @doc "Redirect to the given URL with a 302 status."
  def redirect(conn, to: url) do
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "")
  end

  @doc "Send a file as a download response with optional filename and content type."
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

  @doc "Set the HTTP status code on the connection."
  def put_status(conn, status) do
    %{conn | status: status}
  end

  @doc "Get the current HTTP status code from the connection."
  def get_status(conn), do: conn.status

  @doc "Get the parsed body parameters from the connection."
  def get_body_params(conn), do: conn.body_params

  @doc "Get the query string parameters from the connection."
  def get_query_params(conn), do: conn.query_params

  @doc "Get the first value of a request header by name (case-insensitive)."
  def req_header(conn, key), do: get_req_header(conn, String.downcase(key)) |> List.first()

  @doc "Get a session value by key."
  def get_session(conn, key) do
    session = Map.get(conn.assigns, :__session__, %{})
    Map.get(session, key)
  end

  @doc "Store a value in the session under the given key."
  def put_session(conn, key, value) do
    session = Map.get(conn.assigns, :__session__, %{})
    new_session = Map.put(session, key, value)
    assign(conn, :__session__, new_session)
  end

  @doc "Fetch and parse query parameters from the connection."
  def fetch_query_params(conn, opts \\ []) do
    Plug.Conn.fetch_query_params(conn, opts)
  end

  @doc "Fetch and parse body parameters from the connection."
  def fetch_body_params(conn, _parsers \\ []) do
    conn
  end
end
