defmodule Hibana.Plugins.HealthCheckTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.HealthCheck.init([])
      assert opts.checks == []
      assert opts.path == "/health"
    end

    test "allows custom options" do
      opts = Hibana.Plugins.HealthCheck.init(checks: [:memory], path: "/status")
      assert opts.checks == [:memory]
      assert opts.path == "/status"
    end
  end

  describe "call/2" do
    test "returns conn for non-health path" do
      conn = Plug.Test.conn(:get, "/users")
      opts = %{path: "/health"}
      result = Hibana.Plugins.HealthCheck.call(conn, opts)
      assert %Plug.Conn{} = result
    end

    test "returns health status for health path" do
      conn = Plug.Test.conn(:get, "/health")
      opts = %{path: "/health", checks: []}
      conn = Hibana.Plugins.HealthCheck.call(conn, opts)
      assert conn.status == 200
      assert conn.halted == true
    end
  end

  describe "register_check/2" do
    test "registers a custom health check" do
      name = "custom_check_#{:rand.uniform(10000)}"
      :ok = Hibana.Plugins.HealthCheck.register_check(name, fn -> :ok end)
    end
  end
end
