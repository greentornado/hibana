defmodule Hibana.Plugins.JWTTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.JWT

  describe "init/1" do
    test "raises without secret" do
      assert_raise ArgumentError, ~r/requires a :secret option/, fn ->
        JWT.init([])
      end
    end

    test "sets default options with secret" do
      opts = JWT.init(secret: "test_secret")
      assert opts.secret == "test_secret"
      assert opts.algorithm == :HS256
      assert opts.scheme == "Bearer"
    end

    test "allows custom options" do
      opts = JWT.init(secret: "my_secret", algorithm: :HS512, scheme: "Token")
      assert opts.secret == "my_secret"
      assert opts.algorithm == :HS512
      assert opts.scheme == "Token"
    end
  end

  describe "call/2" do
    test "returns 401 for missing token" do
      conn = Plug.Test.conn(:get, "/protected")
      opts = JWT.init(secret: "test_secret")
      result = JWT.call(conn, opts)
      assert result.status == 401
      assert result.halted == true
    end

    test "returns 401 for invalid token" do
      conn =
        Plug.Test.conn(:get, "/protected")
        |> Plug.Conn.put_req_header("authorization", "Bearer invalid_token")

      opts = JWT.init(secret: "test_secret")
      result = JWT.call(conn, opts)
      assert result.status == 401
      assert result.halted == true
    end

    test "allows valid token" do
      secret = "test_secret_key_for_jwt"
      token = JWT.sign(%{"sub" => "user123"}, secret, exp: 3600)

      conn =
        Plug.Test.conn(:get, "/protected")
        |> Plug.Conn.put_req_header("authorization", "Bearer #{token}")

      opts = JWT.init(secret: secret)
      result = JWT.call(conn, opts)
      assert result.assigns[:jwt_claims] != nil
      assert result.assigns[:current_user] == "user123"
      assert result.halted == false
    end
  end

  describe "sign/3 and verify/2" do
    test "signs and verifies a token" do
      secret = "test_secret_key"
      claims = %{"sub" => "user123", "name" => "Test User"}
      token = JWT.sign(claims, secret, exp: 3600)

      assert is_binary(token)

      {:ok, decoded} = JWT.verify(token, secret)
      assert decoded["sub"] == "user123"
      assert decoded["name"] == "Test User"
    end
  end

  describe "decode/1" do
    test "returns error for invalid token" do
      result = JWT.decode("invalid_token")
      assert {:error, :invalid_token} = result
    end

    test "decodes a valid token without verification" do
      secret = "test_secret"
      token = JWT.sign(%{"sub" => "user123"}, secret)
      {:ok, claims} = JWT.decode(token)
      assert claims["sub"] == "user123"
    end
  end
end
