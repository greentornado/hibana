defmodule Hibana.Plugins.TelemetryDashboardTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.TelemetryDashboard

  describe "init/1" do
    test "sets default path" do
      opts = TelemetryDashboard.init([])
      assert opts.path == "/dashboard"
    end

    test "accepts custom path" do
      opts = TelemetryDashboard.init(path: "/metrics")
      assert opts.path == "/metrics"
    end
  end

  describe "call/2" do
    test "returns HTML dashboard at configured path" do
      opts = TelemetryDashboard.init(path: "/dashboard")

      conn =
        Plug.Test.conn(:get, "/dashboard")
        |> TelemetryDashboard.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body =~ "Hibana Dashboard"
      assert conn.resp_body =~ "Total Requests"
      assert conn.resp_body =~ "Memory"
    end

    test "non-dashboard path passes through" do
      opts = TelemetryDashboard.init(path: "/dashboard")

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> TelemetryDashboard.call(opts)

      refute conn.halted
    end

    test "POST to dashboard path passes through" do
      opts = TelemetryDashboard.init(path: "/dashboard")

      conn =
        Plug.Test.conn(:post, "/dashboard")
        |> TelemetryDashboard.call(opts)

      refute conn.halted
    end
  end
end
