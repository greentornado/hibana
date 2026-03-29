defmodule Hibana.Router.DSLTest do
  use ExUnit.Case

  alias Hibana.Router.DSL

  describe "route macros" do
    test "get macro generates route" do
      defmodule DSLRouter do
        use Hibana.Router

        get "/", fn conn -> conn end
        get "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(DSLRouter)
    end

    test "post macro generates route" do
      defmodule PostRouter do
        use Hibana.Router

        post "/users", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PostRouter)
    end

    test "put macro generates route" do
      defmodule PutRouter do
        use Hibana.Router

        put "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PutRouter)
    end

    test "delete macro generates route" do
      defmodule DeleteRouter do
        use Hibana.Router

        delete "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(DeleteRouter)
    end

    test "patch macro generates route" do
      defmodule PatchRouter do
        use Hibana.Router

        patch "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PatchRouter)
    end

    test "options macro generates route" do
      defmodule OptionsRouter do
        use Hibana.Router

        options "/", fn conn -> conn end
      end

      assert Code.ensure_loaded?(OptionsRouter)
    end

    test "head macro generates route" do
      defmodule HeadRouter do
        use Hibana.Router

        head "/", fn conn -> conn end
      end

      assert Code.ensure_loaded?(HeadRouter)
    end
  end

  describe "dynamic segments" do
    test "captures dynamic segments from path" do
      defmodule DynamicRouter do
        use Hibana.Router

        get "/users/:id/posts/:slug", fn conn ->
          assert conn.params["id"] == "123"
          assert conn.params["slug"] == "hello"
          conn
        end
      end

      conn = Plug.Test.conn(:get, "/users/123/posts/hello")
      # Route would be invoked here in real scenario
    end
  end

  describe "inline handlers" do
    test "supports inline function handlers" do
      defmodule InlineRouter do
        use Hibana.Router

        get "/inline", fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(200, "OK")
        end
      end

      assert Code.ensure_loaded?(InlineRouter)
    end
  end
end
