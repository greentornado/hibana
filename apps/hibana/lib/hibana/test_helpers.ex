defmodule Hibana.TestHelpers do
  @moduledoc """
  Test helpers for Hibana applications. Provides convenient functions
  for testing controllers, routes, and plugs.

  ## Usage

      defmodule MyApp.UserControllerTest do
        use ExUnit.Case
        use Hibana.TestHelpers

        test "index returns users" do
          conn = get("/users")
          assert json_response(conn, 200) == %{"users" => []}
        end

        test "create user" do
          conn = post("/users", %{name: "Alice", email: "alice@test.com"})
          assert json_response(conn, 201)["name"] == "Alice"
        end
      end
  """

  defmacro __using__(opts \\ []) do
    quote do
      import Hibana.TestHelpers
      import Plug.Conn
      import Plug.Test

      @router Keyword.get(unquote(opts), :router)
      @endpoint Keyword.get(unquote(opts), :endpoint)
    end
  end

  @doc """
  Makes a test GET request and returns the resulting connection.

  ## Parameters

    - `path` - The request path (e.g., `"/users"`)
    - `params` - Query parameters as a map (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct with the request populated.

  ## Examples

      ```elixir
      conn = get("/users")
      conn = get("/users", %{page: 1}, [{"accept", "application/json"}])
      ```
  """
  def get(path, params \\ %{}, headers \\ []) do
    build_conn(:get, path, params, headers)
  end

  @doc """
  Makes a test POST request with a JSON body.

  Automatically sets `Content-Type: application/json` when body is a map.

  ## Parameters

    - `path` - The request path
    - `body` - The request body (map is JSON-encoded) (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct.

  ## Examples

      ```elixir
      conn = post("/users", %{name: "Alice", email: "alice@test.com"})
      ```
  """
  def post(path, body \\ %{}, headers \\ []) do
    build_conn(:post, path, body, headers)
  end

  @doc """
  Makes a test PUT request with a JSON body.

  ## Parameters

    - `path` - The request path
    - `body` - The request body (map is JSON-encoded) (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct.
  """
  def put(path, body \\ %{}, headers \\ []) do
    build_conn(:put, path, body, headers)
  end

  @doc """
  Makes a test PATCH request with a JSON body.

  ## Parameters

    - `path` - The request path
    - `body` - The request body (map is JSON-encoded) (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct.
  """
  def patch(path, body \\ %{}, headers \\ []) do
    build_conn(:patch, path, body, headers)
  end

  @doc """
  Makes a test DELETE request.

  ## Parameters

    - `path` - The request path
    - `params` - Request parameters (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct.
  """
  def delete(path, params \\ %{}, headers \\ []) do
    build_conn(:delete, path, params, headers)
  end

  @doc """
  Asserts the response has the expected status code and JSON content type,
  then decodes and returns the JSON body.

  Raises `ExUnit.AssertionError` if the status code or content type
  does not match.

  ## Parameters

    - `conn` - The response connection
    - `status` - The expected HTTP status code

  ## Returns

  The decoded JSON body as a map.

  ## Examples

      ```elixir
      data = json_response(conn, 200)
      assert data["users"] == []

      data = json_response(conn, 201)
      assert data["id"]
      ```
  """
  def json_response(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}\nBody: #{conn.resp_body}"
    end

    case List.keyfind(conn.resp_headers, "content-type", 0) do
      {"content-type", content_type} ->
        unless String.contains?(content_type, "application/json") do
          raise ExUnit.AssertionError,
            message: "Expected JSON content-type, got: #{content_type}"
        end

      nil ->
        raise ExUnit.AssertionError,
          message: "No content-type header found in response"
    end

    Jason.decode!(conn.resp_body)
  end

  @doc """
  Returns the decoded JSON body without checking status code.
  Assumes status 200 if not specified.
  """
  def json_response(conn) do
    json_response(conn, 200)
  end

  @doc """
  Asserts the response has the expected status code and returns the HTML body.

  ## Parameters

    - `conn` - The response connection
    - `status` - The expected HTTP status code

  ## Returns

  The response body as a string.
  """
  def html_response(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}"
    end

    conn.resp_body
  end

  @doc """
  Returns the HTML body without checking status code.
  Assumes status 200 if not specified.
  """
  def html_response(conn) do
    html_response(conn, 200)
  end

  @doc """
  Asserts the response has the expected status code and returns the text body.

  ## Parameters

    - `conn` - The response connection
    - `status` - The expected HTTP status code

  ## Returns

  The response body as a string.
  """
  def text_response(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}"
    end

    conn.resp_body
  end

  @doc """
  Returns the text body without checking status code.
  Assumes status 200 if not specified.
  """
  def text_response(conn) do
    text_response(conn, 200)
  end

  @doc """
  Asserts the response is a redirect (301 or 302) to the specified path.

  ## Parameters

    - `conn` - The response connection
    - `to:` - The expected redirect URL

  ## Returns

  The `location` header value.

  ## Examples

      ```elixir
      assert_redirect(conn, to: "/login")
      ```
  """
  def assert_redirect(conn, to: path) do
    unless conn.status in [301, 302] do
      raise ExUnit.AssertionError,
        message: "Expected redirect (301/302), got #{conn.status}"
    end

    [location] = Plug.Conn.get_resp_header(conn, "location")

    unless location == path do
      raise ExUnit.AssertionError,
        message: "Expected redirect to #{path}, got #{location}"
    end

    location
  end

  @doc """
  Asserts that the response has the expected status code.

  ## Parameters

    - `conn` - The response connection
    - `status` - The expected HTTP status code

  ## Returns

  The status code if it matches, otherwise raises an error.
  """
  def assert_status(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}"
    end

    conn.status
  end

  @doc """
  Asserts that a response header has the expected value.

  ## Parameters

    - `conn` - The response connection
    - `header` - The header name (lowercase)
    - `value` - The expected header value

  ## Returns

  The header value if it matches, otherwise raises an error.
  """
  def assert_header(conn, header, value) do
    actual = Plug.Conn.get_resp_header(conn, header)

    unless actual == [value] do
      raise ExUnit.AssertionError,
        message: "Expected header #{header} to be #{inspect(value)}, got #{inspect(actual)}"
    end

    value
  end

  @doc """
  Asserts that the JSON response body matches the expected value.

  ## Parameters

    - `conn` - The response connection (must have JSON content-type)
    - `expected` - The expected decoded JSON value

  ## Returns

  The decoded JSON body if it matches, otherwise raises an error.
  """
  def assert_json(conn, expected) do
    body = json_response(conn, conn.status)

    unless body == expected do
      raise ExUnit.AssertionError,
        message: "Expected JSON #{inspect(expected)}, got #{inspect(body)}"
    end

    body
  end

  @doc """
  Builds a test connection with the given method, path, body, and headers.

  For POST, PUT, and PATCH requests with a map body, automatically sets
  `Content-Type: application/json`.

  ## Parameters

    - `method` - The HTTP method atom (`:get`, `:post`, `:put`, `:patch`, `:delete`)
    - `path` - The request path
    - `body` - The request body (map is JSON-encoded) (default: `%{}`)
    - `headers` - List of `{key, value}` header tuples (default: `[]`)

  ## Returns

  A `Plug.Conn` struct.
  """
  def build_conn(method, path, body \\ %{}, headers \\ []) do
    conn = Plug.Test.conn(method, path, encode_body(body))

    conn =
      Enum.reduce(headers, conn, fn {key, value}, conn ->
        Plug.Conn.put_req_header(conn, key, value)
      end)

    if method in [:post, :put, :patch] and is_map(body) do
      conn
      |> Plug.Conn.put_req_header("content-type", "application/json")
    else
      conn
    end
  end

  @doc """
  Adds a Bearer token authorization header to the connection.

  ## Parameters

    - `conn` - The test connection
    - `token` - The Bearer token string

  ## Returns

  The connection with the `authorization` header set.

  ## Examples

      ```elixir
      conn = get("/protected") |> with_auth("eyJhbGci...")
      ```
  """
  def with_auth(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc """
  Adds a Basic authentication header to the connection.

  ## Parameters

    - `conn` - The test connection
    - `username` - The username
    - `password` - The password

  ## Returns

  The connection with the `authorization` header set to `Basic <encoded>`.

  ## Examples

      ```elixir
      conn = get("/admin") |> with_basic_auth("admin", "secret")
      ```
  """
  def with_basic_auth(conn, username, password) do
    encoded = Base.encode64("#{username}:#{password}")
    Plug.Conn.put_req_header(conn, "authorization", "Basic #{encoded}")
  end

  defp encode_body(body) when is_map(body), do: Jason.encode!(body)
  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(_), do: ""
end
