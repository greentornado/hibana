defmodule Hibana.CompiledRouterTest do
  use ExUnit.Case, async: true
  import Plug.Test

  defmodule TestController do
    use Hibana.Controller

    def index(conn), do: json(conn, %{action: "index"})
    def show(conn), do: json(conn, %{action: "show", id: conn.params["id"]})
    def create(conn), do: json(conn, %{action: "create"})
    def update(conn), do: json(conn, %{action: "update", id: conn.params["id"]})
    def delete_action(conn), do: json(conn, %{action: "delete", id: conn.params["id"]})
  end

  defmodule TestRouter do
    use Hibana.CompiledRouter

    get "/", TestController, :index
    get "/users", TestController, :index
    post "/users", TestController, :create
    get "/users/:id", TestController, :show
    put "/users/:id", TestController, :update
    delete "/users/:id", TestController, :delete_action

    get "/hello" do
      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(200, "Hello World!")
    end
  end

  defp call(method, path) do
    conn = conn(method, path) |> Plug.Conn.fetch_query_params()
    TestRouter.call(conn, TestRouter.init([]))
  end

  test "GET / dispatches to index" do
    conn = call(:get, "/")
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"action" => "index"}
  end

  test "GET /users dispatches to index" do
    conn = call(:get, "/users")
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"action" => "index"}
  end

  test "POST /users dispatches to create" do
    conn = call(:post, "/users")
    assert conn.status == 200
    assert Jason.decode!(conn.resp_body) == %{"action" => "create"}
  end

  test "GET /users/:id extracts params" do
    conn = call(:get, "/users/42")
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["action"] == "show"
    assert body["id"] == "42"
  end

  test "PUT /users/:id dispatches to update with params" do
    conn = call(:put, "/users/99")
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["action"] == "update"
    assert body["id"] == "99"
  end

  test "DELETE /users/:id dispatches to delete with params" do
    conn = call(:delete, "/users/7")
    assert conn.status == 200
    body = Jason.decode!(conn.resp_body)
    assert body["action"] == "delete"
    assert body["id"] == "7"
  end

  test "returns 404 for unknown routes" do
    conn = call(:get, "/nonexistent")
    assert conn.status == 404
    assert conn.resp_body == "Not Found"
  end

  test "returns 404 for wrong method on existing path" do
    conn = call(:delete, "/")
    assert conn.status == 404
  end

  test "inline handler block works" do
    conn = call(:get, "/hello")
    assert conn.status == 200
    assert conn.resp_body == "Hello World!"
  end

  test "routes/0 returns registered routes" do
    routes = TestRouter.routes()
    assert is_list(routes)
    assert length(routes) > 0
  end
end
