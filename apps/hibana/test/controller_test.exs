defmodule Hibana.ControllerTest do
  use ExUnit.Case, async: true

  describe "put_status/2" do
    test "updates the status code" do
      conn = %Plug.Conn{status: 200}
      result = Hibana.Controller.put_status(conn, 404)
      assert result.status == 404
    end
  end

  describe "get_status/1" do
    test "returns the status code" do
      conn = %Plug.Conn{status: 201}
      assert Hibana.Controller.get_status(conn) == 201
    end
  end

  describe "get_body_params/1" do
    test "returns body params" do
      conn = %Plug.Conn{body_params: %{"name" => "test"}}
      assert Hibana.Controller.get_body_params(conn) == %{"name" => "test"}
    end
  end

  describe "get_query_params/1" do
    test "returns query params" do
      conn = %Plug.Conn{query_params: %{"page" => "1"}}
      assert Hibana.Controller.get_query_params(conn) == %{"page" => "1"}
    end
  end

  describe "req_header/2" do
    test "returns request header value" do
      conn = %Plug.Conn{req_headers: [{"content-type", "application/json"}]}
      assert Hibana.Controller.req_header(conn, "Content-Type") == "application/json"
    end

    test "returns nil for missing header" do
      conn = %Plug.Conn{req_headers: []}
      assert Hibana.Controller.req_header(conn, "X-Custom") == nil
    end
  end

  describe "get_session/2" do
    test "returns session value from __session__ in assigns" do
      conn = %Plug.Conn{assigns: %{__session__: %{user_id: 123}}}
      assert Hibana.Controller.get_session(conn, :user_id) == 123
    end

    test "returns nil for missing session key" do
      conn = %Plug.Conn{assigns: %{}}
      assert Hibana.Controller.get_session(conn, :user_id) == nil
    end
  end

  describe "put_session/3" do
    test "adds value to __session__ in assigns" do
      conn = %Plug.Conn{}
      result = Hibana.Controller.put_session(conn, :user_id, 123)
      assert result.assigns[:__session__][:user_id] == 123
    end
  end

  describe "fetch_query_params/2" do
    test "fetches query params" do
      conn = Plug.Test.conn(:get, "/?page=1")
      result = Hibana.Controller.fetch_query_params(conn)
      assert result.query_params != nil
    end
  end

  describe "fetch_body_params/2" do
    test "fetches body params" do
      conn = Plug.Test.conn(:get, "/")
      result = Hibana.Controller.fetch_body_params(conn)
      assert result.body_params != nil
    end
  end
end
