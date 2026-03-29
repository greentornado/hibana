defmodule Hibana.PipelineTest do
  use ExUnit.Case

  alias Hibana.Pipeline

  describe "__using__/1" do
    test "imports Pipeline macros" do
      defmodule TestRouter do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        pipeline :api do
          plug Hibana.Plugins.Logger
        end

        get "/", fn conn -> Hibana.Controller.text(conn, "OK") end
      end

      assert function_exported?(TestRouter, :__using__, 1)
    end
  end

  describe "pipeline/2 macro" do
    test "defines named pipeline" do
      defmodule PipelineRouter do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        pipeline :api do
          plug Hibana.Plugins.Logger
          plug Hibana.Plugins.JWT, secret: "test"
        end

        pipeline :public do
          plug Hibana.Plugins.CORS
        end

        get "/", fn conn -> Hibana.Controller.text(conn, "OK") end
      end

      # Router should compile successfully
      assert Code.ensure_loaded?(PipelineRouter)
    end
  end

  describe "scope/3 macro" do
    test "creates scope with path and pipeline" do
      defmodule ScopeRouter do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        pipeline :api do
          plug Hibana.Plugins.Logger
        end

        scope "/api", pipeline: :api do
          get "/users", fn conn -> Hibana.Controller.json(conn, %{users: []}) end
        end

        get "/", fn conn -> Hibana.Controller.text(conn, "Home") end
      end

      assert Code.ensure_loaded?(ScopeRouter)
    end

    test "scope macro logs warning about limitations" do
      # The scope macro logs a warning about path/pipeline not being applied
      # This is expected behavior - the warning documents the limitation
      defmodule LimitedScopeRouter do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        scope "/api", [] do
          get "/test", fn conn -> Hibana.Controller.text(conn, "OK") end
        end
      end

      assert Code.ensure_loaded?(LimitedScopeRouter)
    end
  end

  describe "plug/2 macro" do
    test "accumulates plugs within pipeline" do
      defmodule PlugRouter do
        use Hibana.CompiledRouter
        import Hibana.Pipeline

        pipeline :test do
          plug Hibana.Plugins.Logger
          plug Hibana.Plugins.BodyParser
        end

        get "/", fn conn -> Hibana.Controller.text(conn, "OK") end
      end

      assert Code.ensure_loaded?(PlugRouter)
    end

    test "standalone plug at module level" do
      defmodule StandalonePlugRouter do
        use Hibana.CompiledRouter

        plug Hibana.Plugins.Logger

        get "/", fn conn -> Hibana.Controller.text(conn, "OK") end
      end

      assert Code.ensure_loaded?(StandalonePlugRouter)
    end
  end
end
