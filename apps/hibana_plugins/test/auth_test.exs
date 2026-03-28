defmodule Hibana.Plugins.AuthTest do
  use ExUnit.Case
  use Plug.Test

  alias Hibana.Plugins.Auth

  describe "Auth plugin" do
    test "halts connection with 401 when no credentials provided" do
      conn = conn(:get, "/protected")
      opts = Auth.init(realm: "Test")
      conn = Auth.call(conn, opts)

      assert conn.halted
      assert conn.status == 401
      assert get_resp_header(conn, "www-authenticate") == ["Basic realm=\"Test\""]
    end

    test "allows connection with valid credentials" do
      credentials = Base.encode64("admin:secret")

      conn =
        conn(:get, "/protected")
        |> put_req_header("authorization", "Basic #{credentials}")

      opts =
        Auth.init(
          realm: "Test",
          validator: fn username, password ->
            username == "admin" && password == "secret"
          end
        )

      conn = Auth.call(conn, opts)

      refute conn.halted
      assert conn.status != 401
    end

    test "halts connection with invalid credentials" do
      credentials = Base.encode64("admin:wrongpassword")

      conn =
        conn(:get, "/protected")
        |> put_req_header("authorization", "Basic #{credentials}")

      opts =
        Auth.init(
          realm: "Test",
          validator: fn username, password ->
            username == "admin" && password == "secret"
          end
        )

      conn = Auth.call(conn, opts)

      assert conn.halted
      assert conn.status == 401
    end
  end
end
