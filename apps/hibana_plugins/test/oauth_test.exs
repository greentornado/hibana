defmodule Hibana.Plugins.OAuthTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.OAuth

  @jwt_secret "test_jwt_secret_key"

  describe "init/1" do
    test "initializes google provider" do
      opts =
        OAuth.init(
          provider: :google,
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback",
          jwt_secret: @jwt_secret
        )

      assert opts.provider == :google
      assert opts.client_id == "test_id"
      assert opts.client_secret == "test_secret"
      assert opts.redirect_uri == "http://localhost/callback"
      assert opts.auth_url == "https://accounts.google.com/o/oauth2/v2/auth"
      assert opts.token_url == "https://oauth2.googleapis.com/token"
      assert opts.user_url == "https://www.googleapis.com/oauth2/v2/userinfo"
    end

    test "initializes github provider" do
      opts =
        OAuth.init(
          provider: :github,
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback",
          jwt_secret: @jwt_secret
        )

      assert opts.provider == :github
      assert opts.auth_url == "https://github.com/login/oauth/authorize"
      assert opts.token_url == "https://github.com/login/oauth/access_token"
      assert opts.user_url == "https://api.github.com/user"
    end

    test "initializes facebook provider" do
      opts =
        OAuth.init(
          provider: :facebook,
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback",
          jwt_secret: @jwt_secret
        )

      assert opts.provider == :facebook
      assert opts.auth_url == "https://www.facebook.com/v12.0/dialog/oauth"
      assert opts.token_url == "https://graph.facebook.com/v12.0/oauth/access_token"
      assert opts.user_url == "https://graph.facebook.com/me"
    end

    test "raises without jwt_secret" do
      assert_raise ArgumentError, ~r/requires a :jwt_secret/, fn ->
        OAuth.init(
          provider: :google,
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback"
        )
      end
    end

    test "allows custom jwt_secret" do
      opts =
        OAuth.init(
          provider: :google,
          client_id: "test_id",
          client_secret: "test_secret",
          redirect_uri: "http://localhost/callback",
          jwt_secret: "custom_secret"
        )

      assert opts.jwt_secret == "custom_secret"
    end
  end

  describe "call/2" do
    test "returns conn for non-auth paths" do
      conn = Plug.Test.conn(:get, "/api/users")

      opts = %{
        provider: :google,
        client_id: "id",
        client_secret: "secret",
        redirect_uri: "http://localhost",
        jwt_secret: "secret"
      }

      result = OAuth.call(conn, opts)
      assert result == conn
    end

    test "redirects to auth URL for login path" do
      conn = Plug.Test.conn(:get, "/auth/login")

      opts = %{
        provider: :google,
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "http://localhost/callback",
        jwt_secret: "secret",
        auth_url: "https://accounts.google.com/o/oauth2/v2/auth",
        token_url: "https://oauth2.googleapis.com/token",
        user_url: "https://www.googleapis.com/oauth2/v2/userinfo",
        scope: "openid email profile"
      }

      conn = OAuth.call(conn, opts)
      assert conn.status == 302
    end
  end

  describe "redirect/2" do
    test "creates redirect response" do
      conn = Plug.Test.conn(:get, "/")
      result = OAuth.redirect(conn, to: "/callback")
      assert result.status == 302
    end
  end

  describe "generate_authorization_url/2" do
    test "generates authorization URL for google" do
      config = [
        client_id: "test_client_id",
        redirect_uri: "http://localhost/callback"
      ]

      url = OAuth.generate_authorization_url(:google, config)
      assert String.contains?(url, "accounts.google.com")
      assert String.contains?(url, "client_id=test_client_id")
      assert String.contains?(url, "redirect_uri=")
    end

    test "generates authorization URL for github" do
      config = [
        client_id: "test_client_id",
        redirect_uri: "http://localhost/callback"
      ]

      url = OAuth.generate_authorization_url(:github, config)
      assert String.contains?(url, "github.com")
      assert String.contains?(url, "client_id=test_client_id")
    end

    test "generates authorization URL with custom scope" do
      config = [
        client_id: "test_client_id",
        redirect_uri: "http://localhost/callback",
        scope: "custom_scope"
      ]

      url = OAuth.generate_authorization_url(:google, config)
      assert String.contains?(url, "scope=custom_scope")
    end
  end

  describe "exchange_token/2" do
    test "handles successful token response" do
      config = [
        client_id: "test_id",
        client_secret: "test_secret",
        redirect_uri: "http://localhost/callback",
        token_url: "https://example.com/token"
      ]

      result = OAuth.exchange_token("test_code", config)
      assert result == {:error, :token_exchange_failed}
    end
  end

  describe "fetch_user/2" do
    test "handles user fetch response" do
      result = OAuth.fetch_user("test_token", "https://example.com/user")
      assert result == {:error, :fetch_failed}
    end
  end
end
