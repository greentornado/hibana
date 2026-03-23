defmodule Hibana.Plugins.GracefulShutdownTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns default options" do
      opts = Hibana.Plugins.GracefulShutdown.init([])
      assert opts.timeout == 30_000
      assert opts.drain == true
    end

    test "allows custom options" do
      opts = Hibana.Plugins.GracefulShutdown.init(timeout: 60_000, drain: false)
      assert opts.timeout == 60_000
      assert opts.drain == false
    end
  end

  describe "call/2" do
    test "returns conn with drain mode assigned" do
      conn = Plug.Test.conn(:get, "/users")

      opts = %{timeout: 30_000, drain: true}
      result = Hibana.Plugins.GracefulShutdown.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns.drain_mode == true
      assert {"x-shutdown-timeout", "30000"} in result.resp_headers
    end

    test "sets drain mode to false when disabled" do
      conn = Plug.Test.conn(:get, "/users")

      opts = %{timeout: 30_000, drain: false}
      result = Hibana.Plugins.GracefulShutdown.call(conn, opts)
      assert result.assigns.drain_mode == false
    end
  end

  describe "start_shutdown/1" do
    test "returns ok after timeout" do
      result = Hibana.Plugins.GracefulShutdown.start_shutdown(10)
      assert result == :ok
    end
  end

  describe "drain_requests/1" do
    test "returns ok after timeout" do
      result = Hibana.Plugins.GracefulShutdown.drain_requests(10)
      assert result == :ok
    end
  end

  describe "notify_shutdown/0" do
    test "function is defined and callable" do
      # notify_shutdown calls System.stop(0) which would terminate the VM,
      # so we only verify the function exists
      Code.ensure_loaded!(Hibana.Plugins.GracefulShutdown)
      assert function_exported?(Hibana.Plugins.GracefulShutdown, :notify_shutdown, 0)
    end
  end
end
