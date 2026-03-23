defmodule Hibana.Plugins.ScopedCORSTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.ScopedCORS

  describe "init/1" do
    test "compiles rules into regex patterns" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/public/*", origins: ["*"]},
            {"/api/admin/*", origins: ["https://admin.example.com"]}
          ]
        )

      assert length(opts.rules) == 2
      assert Enum.all?(opts.rules, fn {regex, _} -> is_struct(regex, Regex) end)
    end

    test "sets empty default" do
      opts = ScopedCORS.init([])
      assert opts.rules == []
      assert opts.default == []
    end
  end

  describe "call/2" do
    test "sets CORS headers for matching origin" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/*", origins: ["https://app.example.com"], credentials: true}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> Plug.Conn.put_req_header("origin", "https://app.example.com")
        |> ScopedCORS.call(opts)

      assert Plug.Conn.get_resp_header(conn, "access-control-allow-origin") == [
               "https://app.example.com"
             ]

      assert Plug.Conn.get_resp_header(conn, "access-control-allow-credentials") == ["true"]
    end

    test "passes through without origin header" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/*", origins: ["*"]}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> ScopedCORS.call(opts)

      assert Plug.Conn.get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "wildcard origin allows any origin" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/*", origins: ["*"]}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.put_req_header("origin", "https://any-site.com")
        |> ScopedCORS.call(opts)

      assert Plug.Conn.get_resp_header(conn, "access-control-allow-origin") == [
               "https://any-site.com"
             ]
    end

    test "non-matching origin does not get CORS headers" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/*", origins: ["https://allowed.com"]}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.put_req_header("origin", "https://evil.com")
        |> ScopedCORS.call(opts)

      assert Plug.Conn.get_resp_header(conn, "access-control-allow-origin") == []
    end

    test "OPTIONS request returns 204 for preflight" do
      opts =
        ScopedCORS.init(
          rules: [
            {"/api/*", origins: ["*"]}
          ]
        )

      conn =
        Plug.Test.conn(:options, "/api/data")
        |> Plug.Conn.put_req_header("origin", "https://app.com")
        |> ScopedCORS.call(opts)

      assert conn.halted
      assert conn.status == 204
    end
  end
end
