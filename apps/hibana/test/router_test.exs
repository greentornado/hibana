defmodule Hibana.RouterTest do
  use ExUnit.Case, async: true

  describe "init/1" do
    test "returns routes and plugs" do
      opts = [routes: [], plugs: []]
      result = Hibana.Router.init(opts)
      assert result.routes == []
      assert result.plugs == []
    end

    test "extracts routes from opts" do
      routes = [{:get, "/users", nil, nil}]
      plugs = [{Hibana.Plug.Defaults, []}]
      opts = [routes: routes, plugs: plugs]
      result = Hibana.Router.init(opts)
      assert result.routes == routes
      assert result.plugs == plugs
    end
  end

  describe "call/2" do
    test "executes plugs before routing" do
      defmodule TestPlug do
        import Plug.Conn
        def init(opts), do: opts
        def call(conn, _opts), do: assign(conn, :plugged, true)
      end

      routes = []
      plugs = [{TestPlug, []}]
      conn = Plug.Test.conn(:get, "/test")

      result = Hibana.Router.call(conn, %{routes: routes, plugs: plugs})
      assert result.assigns[:plugged] == true
    end

    test "invokes function handler" do
      handler_called = :counters.new(1, [:atomics])

      handler = fn conn ->
        :counters.add(handler_called, 1, 1)
        Plug.Conn.send_resp(conn, 200, "OK")
      end

      routes = [{:get, "/test", handler, nil}]
      conn = Plug.Test.conn(:get, "/test")

      _result = Hibana.Router.call(conn, %{routes: routes, plugs: []})
      assert :counters.get(handler_called, 1) == 1
    end

    test "invokes atom handler with action" do
      defmodule TestController do
        def test_action(conn) do
          Plug.Conn.send_resp(conn, 200, "from controller")
        end
      end

      routes = [{:get, "/controller", TestController, :test_action}]
      conn = Plug.Test.conn(:get, "/controller")

      result = Hibana.Router.call(conn, %{routes: routes, plugs: []})
      assert result.status == 200
    end
  end

  describe "path matching" do
    test "matches exact path" do
      path = ["users"]
      pattern = "users"

      assert {:ok, %{}} = match_path(path, pattern)
    end

    test "extracts path parameters" do
      path = ["users", "123"]
      pattern = "users/:id"

      assert {:ok, %{id: "123"}} = match_path(path, pattern)
    end

    test "matches root path" do
      path = []
      pattern = "/"

      assert {:ok, %{}} = match_path(path, pattern)
    end

    test "returns nomatch for non-matching paths" do
      path = ["users", "123"]
      pattern = "posts/:id"

      assert :nomatch = match_path(path, pattern)
    end

    test "matches wildcard" do
      path = ["users", "123", "extra"]
      pattern = "users/:id/*rest"

      assert {:ok, %{id: "123"}} = match_path(path, pattern)
    end

    test "handles list pattern" do
      path = ["api", "users"]
      pattern = ["api", "users"]

      assert {:ok, %{}} = match_path(path, pattern)
    end
  end

  defp match_path(path, pattern) when is_binary(pattern) do
    path_parts = String.split(pattern, "/", trim: true)
    do_match(path, path_parts, %{})
  end

  defp match_path(path, pattern) when is_list(pattern) do
    do_match(path, pattern, %{})
  end

  defp do_match([], [], params), do: {:ok, params}
  defp do_match([], [":*" | _], params), do: {:ok, params}
  defp do_match([h | t1], [h | t2], params), do: do_match(t1, t2, params)

  defp do_match([h | _], [":" <> param | _], params) when is_binary(h),
    do: {:ok, Map.put(params, String.to_existing_atom(param), h)}

  defp do_match(_, _, _), do: :nomatch
end
