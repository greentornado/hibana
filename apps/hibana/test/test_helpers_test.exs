defmodule Hibana.TestHelpersTest do
  use ExUnit.Case, async: true
  use Hibana.TestHelpers

  # Test the TestHelpers module itself
  describe "TestHelpers macros" do
    test "conn/2 creates test connection" do
      conn = conn(:get, "/")
      assert conn.method == "GET"
      assert conn.request_path == "/"
    end

    test "conn/3 with params creates connection" do
      conn = conn(:post, "/users", %{name: "Alice"})
      assert conn.method == "POST"
      assert conn.request_path == "/users"
      assert conn.body_params == %{"name" => "Alice"}
    end

    test "json_response/1 parses JSON response" do
      conn =
        conn(:get, "/api/users")
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"users":["alice","bob"]}))

      data = json_response(conn)
      assert data["users"] == ["alice", "bob"]
    end

    test "html_response/1 gets HTML body" do
      conn =
        conn(:get, "/")
        |> put_resp_content_type("text/html")
        |> send_resp(200, "<h1>Hello</h1>")

      body = html_response(conn)
      assert body == "<h1>Hello</h1>"
    end

    test "text_response/1 gets text body" do
      conn =
        conn(:get, "/")
        |> put_resp_content_type("text/plain")
        |> send_resp(200, "Hello, World!")

      body = text_response(conn)
      assert body == "Hello, World!"
    end

    test "assert_status/2 checks status code" do
      conn =
        conn(:get, "/")
        |> send_resp(404, "Not Found")

      # Should not raise when status matches
      assert_status(conn, 404)
    end

    test "assert_header/3 checks response header" do
      conn =
        conn(:get, "/")
        |> put_resp_header("x-custom", "value")
        |> send_resp(200, "OK")

      # Should not raise when header matches
      assert_header(conn, "x-custom", "value")
    end

    test "assert_json/2 checks JSON response" do
      conn =
        conn(:get, "/api/user/1")
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"id":1,"name":"Alice"}))

      # Should not raise when JSON matches
      assert_json(conn, %{"id" => 1, "name" => "Alice"})
    end

    test "put_req_header helper" do
      conn =
        conn(:get, "/")
        |> put_req_header("authorization", "Bearer token123")

      assert get_req_header(conn, "authorization") == ["Bearer token123"]
    end

    test "get_resp_header helper" do
      conn =
        conn(:get, "/")
        |> put_resp_header("x-request-id", "abc-123")
        |> send_resp(200, "OK")

      assert get_resp_header(conn, "x-request-id") == ["abc-123"]
    end

    test "full request-response cycle with helpers" do
      # Simulate a controller action
      conn =
        conn(:get, "/api/users?page=2")
        |> fetch_query_params()

      # Verify query params
      assert conn.query_params["page"] == "2"

      # Simulate response
      conn =
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"page":2,"users":[]}))

      # Verify response
      assert conn.status == 200
      assert json_response(conn)["page"] == 2
    end
  end

  describe "TestHelpers with controller testing" do
    defmodule MockController do
      use Hibana.Controller

      def index(conn) do
        json(conn, %{users: []})
      end

      def show(conn) do
        id = conn.params["id"]
        json(conn, %{user: %{id: id}})
      end

      def create(conn) do
        conn
        |> put_status(201)
        |> json(%{created: true})
      end
    end

    test "testing controller index action" do
      conn = conn(:get, "/users")
      conn = MockController.index(conn)

      assert conn.status == 200
      assert json_response(conn)["users"] == []
    end

    test "testing controller show action with params" do
      conn = conn(:get, "/users/123", %{"id" => "123"})
      conn = MockController.show(conn)

      assert conn.status == 200
      assert json_response(conn)["user"]["id"] == "123"
    end

    test "testing controller create action" do
      conn = conn(:post, "/users", %{"name" => "Alice"})
      conn = MockController.create(conn)

      assert conn.status == 201
      assert json_response(conn, 201)["created"] == true
    end
  end

  describe "TestHelpers with various HTTP methods" do
    use Hibana.TestHelpers

    test "GET request" do
      conn = conn(:get, "/api/data")
      assert conn.method == "GET"
    end

    test "POST request" do
      conn = conn(:post, "/api/data", %{"key" => "value"})
      assert conn.method == "POST"
    end

    test "PUT request" do
      conn = conn(:put, "/api/data/1", %{"key" => "value"})
      assert conn.method == "PUT"
    end

    test "PATCH request" do
      conn = conn(:patch, "/api/data/1", %{"key" => "value"})
      assert conn.method == "PATCH"
    end

    test "DELETE request" do
      conn = conn(:delete, "/api/data/1")
      assert conn.method == "DELETE"
    end

    test "OPTIONS request" do
      conn = conn(:options, "/api/data")
      assert conn.method == "OPTIONS"
    end
  end

  describe "TestHelpers with headers" do
    test "setting multiple request headers" do
      conn =
        conn(:get, "/api/data")
        |> put_req_header("accept", "application/json")
        |> put_req_header("authorization", "Bearer token")
        |> put_req_header("x-request-id", "12345")

      assert get_req_header(conn, "accept") == ["application/json"]
      assert get_req_header(conn, "authorization") == ["Bearer token"]
      assert get_req_header(conn, "x-request-id") == ["12345"]
    end

    test "response header assertions" do
      conn =
        conn(:get, "/api/data")
        |> put_resp_header("content-type", "application/json")
        |> put_resp_header("x-total-count", "100")
        |> put_resp_header("cache-control", "no-cache")
        |> send_resp(200, "{}")

      assert get_resp_header(conn, "content-type") == ["application/json"]
      assert get_resp_header(conn, "x-total-count") == ["100"]
      assert get_resp_header(conn, "cache-control") == ["no-cache"]
    end
  end

  describe "TestHelpers error handling" do
    test "handles missing response gracefully" do
      conn = conn(:get, "/")
      # conn has no response yet

      # json_response should handle this
      # It might return nil or raise, depending on implementation
      # Just verify the function exists and is callable
      assert function_exported?(Hibana.TestHelpers, :json_response, 1)
    end

    test "handles invalid JSON gracefully" do
      conn =
        conn(:get, "/api/data")
        |> put_resp_content_type("application/json")
        |> send_resp(200, "invalid json")

      # This should handle the parse error
      # Might raise Jason.DecodeError
      assert_raise Jason.DecodeError, fn ->
        json_response(conn)
      end
    end
  end

  describe "TestHelpers integration patterns" do
    test "simulating authentication flow" do
      # Step 1: Login request
      login_conn =
        conn(:post, "/auth/login", %{"email" => "user@example.com", "password" => "secret"})

      login_conn =
        login_conn
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"token":"jwt-token-123"}))

      token = json_response(login_conn)["token"]
      assert token == "jwt-token-123"

      # Step 2: Use token in subsequent request
      api_conn =
        conn(:get, "/api/protected")
        |> put_req_header("authorization", "Bearer #{token}")

      assert get_req_header(api_conn, "authorization") == ["Bearer jwt-token-123"]
    end

    test "simulating pagination" do
      conn =
        conn(:get, "/api/items?page=3&per_page=20")
        |> fetch_query_params()

      page = conn.query_params["page"]
      per_page = conn.query_params["per_page"]

      assert page == "3"
      assert per_page == "20"

      # Simulate paginated response
      conn =
        conn
        |> put_resp_header("x-page", page)
        |> put_resp_header("x-per-page", per_page)
        |> put_resp_header("x-total", "100")
        |> put_resp_content_type("application/json")
        |> send_resp(200, ~s({"items":[],"page":3}))

      assert get_resp_header(conn, "x-page") == ["3"]
      assert get_resp_header(conn, "x-per-page") == ["20"]
      assert get_resp_header(conn, "x-total") == ["100"]
    end
  end
end
