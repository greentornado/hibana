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

  @doc "Make a GET request"
  def get(path, params \\ %{}, headers \\ []) do
    build_conn(:get, path, params, headers)
  end

  @doc "Make a POST request"
  def post(path, body \\ %{}, headers \\ []) do
    build_conn(:post, path, body, headers)
  end

  @doc "Make a PUT request"
  def put(path, body \\ %{}, headers \\ []) do
    build_conn(:put, path, body, headers)
  end

  @doc "Make a PATCH request"
  def patch(path, body \\ %{}, headers \\ []) do
    build_conn(:patch, path, body, headers)
  end

  @doc "Make a DELETE request"
  def delete(path, params \\ %{}, headers \\ []) do
    build_conn(:delete, path, params, headers)
  end

  @doc "Assert and decode JSON response"
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

  @doc "Assert and return HTML response"
  def html_response(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}"
    end

    conn.resp_body
  end

  @doc "Assert and return text response"
  def text_response(conn, status) do
    unless conn.status == status do
      raise ExUnit.AssertionError,
        message: "Expected status #{status}, got #{conn.status}"
    end

    conn.resp_body
  end

  @doc "Assert redirect"
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

  @doc "Build a test connection"
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

  @doc "Add authorization header"
  def with_auth(conn, token) do
    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{token}")
  end

  @doc "Add basic auth header"
  def with_basic_auth(conn, username, password) do
    encoded = Base.encode64("#{username}:#{password}")
    Plug.Conn.put_req_header(conn, "authorization", "Basic #{encoded}")
  end

  defp encode_body(body) when is_map(body), do: Jason.encode!(body)
  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(_), do: ""
end
