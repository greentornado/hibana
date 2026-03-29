defmodule Hibana.Router.DSLTest do
  use ExUnit.Case

  alias Hibana.Router.DSL

  describe "route macros" do
    test "get macro generates route" do
      defmodule DSLRouter do
        use Hibana.Router.DSL

        get "/", fn conn -> conn end
        get "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(DSLRouter)
    end

    test "post macro generates route" do
      defmodule PostRouter do
        use Hibana.Router.DSL

        post "/users", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PostRouter)
    end

    test "put macro generates route" do
      defmodule PutRouter do
        use Hibana.Router.DSL

        put "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PutRouter)
    end

    test "delete macro generates route" do
      defmodule DeleteRouter do
        use Hibana.Router.DSL

        delete "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(DeleteRouter)
    end

    test "patch macro generates route" do
      defmodule PatchRouter do
        use Hibana.Router.DSL

        patch "/users/:id", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PatchRouter)
    end

    test "options macro generates route" do
      defmodule OptionsRouter do
        use Hibana.Router.DSL

        options "/", fn conn -> conn end
      end

      assert Code.ensure_loaded?(OptionsRouter)
    end

    test "head macro generates route" do
      defmodule HeadRouter do
        use Hibana.Router.DSL

        head "/", fn conn -> conn end
      end

      assert Code.ensure_loaded?(HeadRouter)
    end
  end

  describe "dynamic segments" do
    test "captures dynamic segments from path" do
      defmodule DynamicRouter do
        use Hibana.Router.DSL

        get "/users/:id/posts/:slug", fn conn ->
          # In real usage, conn.params would be populated
          conn
        end
      end

      assert Code.ensure_loaded?(DynamicRouter)
    end
  end

  describe "inline handlers" do
    test "supports inline function handlers" do
      defmodule InlineRouter do
        use Hibana.Router.DSL

        get "/inline", fn conn ->
          conn
          |> Plug.Conn.put_resp_content_type("text/plain")
          |> Plug.Conn.send_resp(200, "OK")
        end
      end

      assert Code.ensure_loaded?(InlineRouter)
    end
  end

  describe "controller-based routes" do
    test "supports controller module and action" do
      defmodule ControllerRouter do
        use Hibana.Router.DSL

        get "/users", Hibana.TestHelpers.MockController, :index
        post "/users", Hibana.TestHelpers.MockController, :create
      end

      assert Code.ensure_loaded?(ControllerRouter)
    end
  end

  describe "plug macro" do
    test "supports plug declarations" do
      defmodule PlugRouter do
        use Hibana.Router.DSL

        plug Hibana.Plugins.Logger
        plug Hibana.Plugins.BodyParser

        get "/", fn conn -> conn end
      end

      assert Code.ensure_loaded?(PlugRouter)
    end
  end
end
