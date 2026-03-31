defmodule Hibana.Plugins.SecureHeadersTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  alias Hibana.Plugins.SecureHeaders

  setup do
    conn = conn(:get, "/")
    {:ok, conn: conn}
  end

  describe "init/1" do
    test "returns default security headers" do
      opts = SecureHeaders.init([])
      assert is_list(opts)
    end

    test "accepts custom CSP policy" do
      opts = SecureHeaders.init(content_security_policy: "default-src 'self'")
      assert opts[:content_security_policy] == "default-src 'self'"
    end
  end

  describe "call/2" do
    test "adds security headers to response", %{conn: conn} do
      opts = SecureHeaders.init([])
      conn = SecureHeaders.call(conn, opts)

      # Check for common security headers
      headers = conn.resp_headers

      # X-Content-Type-Options
      assert {"x-content-type-options", "nosniff"} in headers

      # X-Frame-Options
      assert {"x-frame-options", "DENY"} in headers

      # X-XSS-Protection
      assert {"x-xss-protection", "1; mode=block"} in headers
    end

    test "adds Strict-Transport-Security header", %{conn: conn} do
      opts = SecureHeaders.init([])
      conn = SecureHeaders.call(conn, opts)

      headers = conn.resp_headers
      assert Enum.any?(headers, fn {k, _} -> k == "strict-transport-security" end)
    end

    test "adds Content-Security-Policy header", %{conn: conn} do
      opts = SecureHeaders.init(content_security_policy: "default-src 'self'")
      conn = SecureHeaders.call(conn, opts)

      headers = conn.resp_headers
      assert {"content-security-policy", "default-src 'self'"} in headers
    end

    test "allows custom X-Frame-Options", %{conn: conn} do
      opts = SecureHeaders.init(x_frame_options: "SAMEORIGIN")
      conn = SecureHeaders.call(conn, opts)

      headers = conn.resp_headers
      assert {"x-frame-options", "SAMEORIGIN"} in headers
    end

    test "allows disabling specific headers", %{conn: conn} do
      opts =
        SecureHeaders.init(
          x_frame_options: false,
          x_content_type_options: false
        )

      conn = SecureHeaders.call(conn, opts)

      headers = conn.resp_headers
      refute Enum.any?(headers, fn {name, _} -> name == "x-frame-options" end)
      refute Enum.any?(headers, fn {name, _} -> name == "x-content-type-options" end)
    end
  end

  describe "header generation" do
    test "generates nonce for inline scripts" do
      nonce = SecureHeaders.generate_nonce()
      assert is_binary(nonce)
      assert String.length(nonce) > 16
    end

    test "includes referrer policy" do
      opts = SecureHeaders.init(referrer_policy: "strict-origin-when-cross-origin")
      assert opts[:referrer_policy] == "strict-origin-when-cross-origin"
    end
  end
end
