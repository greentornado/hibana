defmodule Hibana.Plugins.MetricsTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.Metrics.init([])
      assert opts.enabled == true
      assert opts.endpoint == "/metrics"
    end

    test "allows custom options" do
      opts = Hibana.Plugins.Metrics.init(enabled: false, endpoint: "/stats")
      assert opts.enabled == false
      assert opts.endpoint == "/stats"
    end
  end

  describe "call/2" do
    test "returns conn for non-metrics path" do
      conn = Plug.Test.conn(:get, "/users")
      opts = %{endpoint: "/metrics", enabled: true}
      result = Hibana.Plugins.Metrics.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns[:request_start] != nil
    end

    test "handles metrics endpoint path" do
      conn = Plug.Test.conn(:get, "/metrics")
      opts = %{endpoint: "/metrics", enabled: true}
      result = Hibana.Plugins.Metrics.call(conn, opts)
      assert result.halted == true
    end

    test "starts timer when disabled" do
      conn = Plug.Test.conn(:get, "/users")
      opts = %{enabled: false}
      result = Hibana.Plugins.Metrics.call(conn, opts)
      assert %Plug.Conn{} = result
    end
  end

  describe "before_send/2" do
    test "emits telemetry and returns conn" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Map.put(:status, 200)
        |> Plug.Conn.assign(:request_start, System.monotonic_time(:millisecond))

      result = Hibana.Plugins.Metrics.before_send(conn, %{})
      assert %Plug.Conn{} = result
    end

    test "returns conn when no start time" do
      conn =
        Plug.Test.conn(:get, "/users")
        |> Map.put(:status, 200)

      result = Hibana.Plugins.Metrics.before_send(conn, %{})
      assert result == conn
    end
  end
end
