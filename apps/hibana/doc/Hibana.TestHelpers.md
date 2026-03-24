# `Hibana.TestHelpers`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/test_helpers.ex#L1)

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

# `assert_redirect`

Assert redirect

# `build_conn`

Build a test connection

# `delete`

Make a DELETE request

# `get`

Make a GET request

# `html_response`

Assert and return HTML response

# `json_response`

Assert and decode JSON response

# `patch`

Make a PATCH request

# `post`

Make a POST request

# `put`

Make a PUT request

# `text_response`

Assert and return text response

# `with_auth`

Add authorization header

# `with_basic_auth`

Add basic auth header

---

*Consult [api-reference.md](api-reference.md) for complete listing*
