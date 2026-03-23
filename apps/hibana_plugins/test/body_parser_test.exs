defmodule Hibana.Plugins.BodyParserTest do
  use ExUnit.Case, async: true
  import Plug.Conn

  describe "init/1" do
    test "sets default options" do
      opts = Hibana.Plugins.BodyParser.init([])
      assert opts.parsers == [:json, :urlencoded]
      assert opts.json_decoder == Jason
    end

    test "allows custom options" do
      opts =
        Hibana.Plugins.BodyParser.init(
          parsers: [:json],
          json_decoder: Jason
        )

      assert opts.parsers == [:json]
      assert opts.json_decoder == Jason
    end
  end

  describe "call/2" do
    test "returns conn for no content-type" do
      conn = Plug.Test.conn(:get, "/")
      conn = %{conn | body_params: %{}}

      opts = %{parsers: [:json, :urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "parses JSON body" do
      body = Jason.encode!(%{name: "test"})

      conn =
        Plug.Test.conn(:post, "/", body)
        |> put_req_header("content-type", "application/json")

      conn = %{conn | body_params: %{}}
      conn = Map.put(conn, :body_buffer, body)

      opts = %{parsers: [:json, :urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert result.body_params == %{"name" => "test"}
    end

    test "handles invalid JSON body" do
      conn =
        Plug.Test.conn(:post, "/", "invalid json")
        |> put_req_header("content-type", "application/json")

      conn = %{conn | body_params: %{}}
      conn = Map.put(conn, :body_buffer, "invalid json")

      opts = %{parsers: [:json, :urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert result.body_params == %{}
    end

    test "parses urlencoded body" do
      conn =
        Plug.Test.conn(:post, "/", "name=test&value=123")
        |> put_req_header("content-type", "application/x-www-form-urlencoded")

      conn = %{conn | body_params: %{}}
      conn = Map.put(conn, :body_buffer, "name=test&value=123")

      opts = %{parsers: [:json, :urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert result.body_params == %{"name" => "test", "value" => "123"}
    end

    test "handles unknown content type" do
      conn =
        Plug.Test.conn(:post, "/", "plain text")
        |> put_req_header("content-type", "text/plain")

      conn = %{conn | body_params: %{}}

      opts = %{parsers: [:json, :urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "skips JSON parser when not in parsers list" do
      body = Jason.encode!(%{name: "test"})

      conn =
        Plug.Test.conn(:post, "/", body)
        |> put_req_header("content-type", "application/json")

      conn = %{conn | body_params: %{}}
      conn = Map.put(conn, :body_buffer, body)

      opts = %{parsers: [:urlencoded], json_decoder: Jason}
      result = Hibana.Plugins.BodyParser.call(conn, opts)
      assert %Plug.Conn{} = result
    end
  end
end
