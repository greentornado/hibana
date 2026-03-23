defmodule Hibana.Plugins.ContentNegotiationTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.ContentNegotiation.init([])
      assert opts.formats == ["json"]
      assert opts.default == "json"
    end

    test "allows custom options" do
      opts = Hibana.Plugins.ContentNegotiation.init(formats: ["json", "xml"], default: "xml")
      assert opts.formats == ["json", "xml"]
      assert opts.default == "xml"
    end
  end

  describe "call/2" do
    test "returns conn with json format assigns" do
      conn = Plug.Test.conn(:get, "/users")

      opts = %{formats: ["json"], default: "json"}
      result = Hibana.Plugins.ContentNegotiation.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns.response_format == "json"
      assert result.assigns.response_content_type == "application/json"
    end

    test "negotiates format from accept header" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Plug.Conn.put_req_header("accept", "text/html")

      opts = %{formats: ["json", "html"], default: "json"}
      result = Hibana.Plugins.ContentNegotiation.call(conn, opts)
      assert result.assigns.response_format == "html"
      assert result.assigns.response_content_type == "text/html"
    end

    test "uses content-type for request format" do
      conn =
        Plug.Test.conn(:post, "/users")
        |> Plug.Conn.put_req_header("accept", "text/html")
        |> Plug.Conn.put_req_header("content-type", "application/json")

      opts = %{formats: ["json", "html"], default: "html"}
      result = Hibana.Plugins.ContentNegotiation.call(conn, opts)
      assert result.assigns.response_format == "json"
    end

    test "falls back to default when no match" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Plug.Conn.put_req_header("accept", "application/xml")

      opts = %{formats: ["json"], default: "json"}
      result = Hibana.Plugins.ContentNegotiation.call(conn, opts)
      assert result.assigns.response_format == "json"
    end
  end

  describe "render_as/3" do
    test "renders as json" do
      conn = Plug.Test.conn(:get, "/")

      result = Hibana.Plugins.ContentNegotiation.render_as(conn, "json", %{key: "value"})
      assert result.status == 200
    end

    test "renders as xml" do
      conn = Plug.Test.conn(:get, "/")

      result = Hibana.Plugins.ContentNegotiation.render_as(conn, "xml", %{key: "value"})
      assert result.status == 200
    end

    test "renders as csv" do
      conn = Plug.Test.conn(:get, "/")

      result = Hibana.Plugins.ContentNegotiation.render_as(conn, "csv", [%{a: 1}])
      assert result.status == 200
    end

    test "renders unknown format as json" do
      conn = Plug.Test.conn(:get, "/")

      result = Hibana.Plugins.ContentNegotiation.render_as(conn, "unknown", %{key: "value"})
      assert result.status == 200
    end
  end
end
