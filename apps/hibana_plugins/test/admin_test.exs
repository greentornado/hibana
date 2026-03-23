defmodule Hibana.Plugins.AdminTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.Admin

  describe "init/1" do
    test "normalizes resources" do
      opts =
        Admin.init(
          path: "/admin",
          resources: [
            {:users, fields: [:name, :email]}
          ]
        )

      assert opts.path == "/admin"
      assert is_list(opts.resources)
      assert length(opts.resources) == 1

      [resource] = opts.resources
      assert resource.name == "users"
      assert resource.fields == [:name, :email]
    end

    test "sets default path" do
      opts = Admin.init(resources: [])
      assert opts.path == "/admin"
    end

    test "sets default title" do
      opts = Admin.init(resources: [])
      assert opts.title == "Admin Dashboard"
    end
  end

  describe "call/2" do
    test "renders dashboard HTML at /admin" do
      opts =
        Admin.init(
          path: "/admin",
          resources: [
            {:users, fields: [:name, :email], list_fn: fn -> [] end}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/admin")
        |> Admin.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body =~ "Admin Dashboard"
      assert conn.resp_body =~ "Users"
    end

    test "non-admin path passes through" do
      opts =
        Admin.init(
          path: "/admin",
          resources: [{:users, fields: [:name]}]
        )

      conn =
        Plug.Test.conn(:get, "/api/users")
        |> Admin.call(opts)

      refute conn.halted
    end

    test "renders resource list page" do
      opts =
        Admin.init(
          path: "/admin",
          resources: [
            {:posts,
             fields: [:title, :body], list_fn: fn -> [%{id: 1, title: "Hello", body: "World"}] end}
          ]
        )

      conn =
        Plug.Test.conn(:get, "/admin/posts")
        |> Admin.call(opts)

      assert conn.halted
      assert conn.status == 200
      assert conn.resp_body =~ "Hello"
    end
  end
end
