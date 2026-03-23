defmodule Hibana.Plugins.LoggerTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "sets default options" do
      opts = Hibana.Plugins.Logger.init([])
      assert opts.log_level == :info
    end

    test "allows custom options" do
      opts = Hibana.Plugins.Logger.init(log_level: :debug)
      assert opts.log_level == :debug
    end
  end

  describe "call/2" do
    test "assigns request start time" do
      conn = Plug.Test.conn(:get, "/users")

      opts = %{log_level: :info}
      result = Hibana.Plugins.Logger.call(conn, opts)
      assert result.assigns[:request_start_time] != nil
    end
  end

  describe "before_send/2" do
    test "logs request with 2xx status" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Map.put(:status, 200)
        |> Plug.Conn.assign(:request_start_time, System.monotonic_time(:millisecond))

      opts = %{log_level: :info}
      result = Hibana.Plugins.Logger.before_send(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "logs request with 4xx status" do
      conn =
        Plug.Test.conn(:get, "/notfound")
        |> Map.put(:status, 404)
        |> Plug.Conn.assign(:request_start_time, System.monotonic_time(:millisecond))

      opts = %{log_level: :info}
      result = Hibana.Plugins.Logger.before_send(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "logs request with 5xx status" do
      conn =
        Plug.Test.conn(:get, "/error")
        |> Map.put(:status, 500)
        |> Plug.Conn.assign(:request_start_time, System.monotonic_time(:millisecond))

      opts = %{log_level: :info}
      result = Hibana.Plugins.Logger.before_send(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "returns conn when no start time" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Map.put(:status, 200)

      opts = %{log_level: :info}
      result = Hibana.Plugins.Logger.before_send(conn, opts)
      assert result == conn
    end
  end
end
