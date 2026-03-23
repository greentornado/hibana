defmodule Hibana.Plugins.ErrorHandlerTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.ErrorHandler.init([])
      assert opts.not_found == :default
      assert opts.server_error == :default
    end

    test "allows custom function options" do
      custom_not_found = fn conn -> conn end
      custom_server_error = fn conn -> conn end

      opts =
        Hibana.Plugins.ErrorHandler.init(
          not_found: custom_not_found,
          server_error: custom_server_error
        )

      assert opts.not_found == custom_not_found
      assert opts.server_error == custom_server_error
    end

    test "allows MFA tuple options" do
      opts =
        Hibana.Plugins.ErrorHandler.init(
          not_found: {MyModule, :not_found},
          server_error: {MyModule, :server_error}
        )

      assert opts.not_found == {MyModule, :not_found}
      assert opts.server_error == {MyModule, :server_error}
    end
  end

  describe "call/2" do
    test "returns conn with error handlers assigned" do
      conn = Plug.Test.conn(:get, "/users")
      opts = Hibana.Plugins.ErrorHandler.init([])
      result = Hibana.Plugins.ErrorHandler.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns.error_not_found == :default
      assert result.assigns.error_server_error == :default
    end
  end

  describe "before_send/2" do
    test "handles 404 status with default handler" do
      conn =
        Plug.Test.conn(:get, "/missing")
        |> Map.put(:status, 404)
        |> Map.put(:state, :set)
        |> Plug.Conn.assign(:error_not_found, :default)

      result = Hibana.Plugins.ErrorHandler.before_send(conn, %{})
      assert result.status == 404
    end

    test "handles 404 status with custom function" do
      custom_fn = fn conn -> %{conn | resp_body: "custom 404"} end

      conn =
        Plug.Test.conn(:get, "/missing")
        |> Map.put(:status, 404)
        |> Map.put(:state, :set)
        |> Plug.Conn.assign(:error_not_found, custom_fn)

      result = Hibana.Plugins.ErrorHandler.before_send(conn, %{})
      assert result.resp_body == "custom 404"
    end

    test "handles 500 status with default handler" do
      conn =
        Plug.Test.conn(:get, "/error")
        |> Map.put(:status, 500)
        |> Map.put(:state, :set)
        |> Plug.Conn.assign(:error_server_error, :default)

      result = Hibana.Plugins.ErrorHandler.before_send(conn, %{})
      assert result.status == 500
    end

    test "passes through for non-error status" do
      conn =
        Plug.Test.conn(:get, "/ok")
        |> Map.put(:status, 200)

      result = Hibana.Plugins.ErrorHandler.before_send(conn, %{})
      assert result.status == 200
    end
  end
end
