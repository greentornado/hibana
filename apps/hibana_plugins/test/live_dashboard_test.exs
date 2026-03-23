defmodule Hibana.Plugins.LiveDashboardTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.LiveDashboard

  describe "init/1" do
    test "returns opts as-is" do
      opts = LiveDashboard.init(path: "/_dashboard")
      assert opts == %{path: "/_dashboard", auth: nil}
    end
  end

  describe "call/2" do
    test "redirects /_dashboard to /_dashboard/overview" do
      opts = LiveDashboard.init(path: "/_dashboard")

      conn =
        Plug.Test.conn(:get, "/_dashboard")
        |> LiveDashboard.call(opts)

      assert conn.halted
      assert conn.status == 302
      assert Plug.Conn.get_resp_header(conn, "location") == ["/_dashboard/overview"]
    end

    test "returns HTML with Hibana Live Dashboard for overview" do
      opts = LiveDashboard.init(path: "/_dashboard")

      conn =
        Plug.Test.conn(:get, "/_dashboard/overview")
        |> LiveDashboard.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body =~ "Hibana Dashboard"
      assert conn.resp_body =~ "Total Memory"
    end

    test "returns HTML for processes page" do
      opts = LiveDashboard.init(path: "/_dashboard")

      conn =
        Plug.Test.conn(:get, "/_dashboard/processes")
        |> LiveDashboard.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body =~ "Processes"
    end

    test "non-dashboard path passes through" do
      opts = LiveDashboard.init(path: "/_dashboard")

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> LiveDashboard.call(opts)

      refute conn.halted
    end
  end
end
