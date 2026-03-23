defmodule Hibana.Plugins.StaticTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "sets default options" do
      opts = Hibana.Plugins.Static.init([])
      assert opts.at == "/"
      assert opts.from == "priv/static"
      assert opts.gzip == false
      assert opts.cache_headers == true
    end

    test "allows custom options" do
      opts = Hibana.Plugins.Static.init(at: "/static", from: "priv/static", gzip: true)
      assert opts.at == "/static"
      assert opts.from == "priv/static"
      assert opts.gzip == true
    end
  end

  describe "call/2" do
    test "returns conn for non-static path" do
      conn = Plug.Test.conn(:get, "/api/users")

      opts = %{at: "/static", from: "priv/static"}
      result = Hibana.Plugins.Static.call(conn, opts)
      assert result == conn
    end

    test "handles file not found" do
      conn = Plug.Test.conn(:get, "/static/nonexistent.txt")

      opts = %{at: "/static", from: "priv/static"}
      result = Hibana.Plugins.Static.call(conn, opts)
      assert result == conn
    end

    test "handles path without matching prefix" do
      conn = Plug.Test.conn(:get, "/other/file.txt")

      opts = %{at: "/static", from: "priv/static"}
      result = Hibana.Plugins.Static.call(conn, opts)
      assert result == conn
    end
  end
end
