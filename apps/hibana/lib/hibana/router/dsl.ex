defmodule Hibana.Router.DSL do
  @moduledoc """
  DSL macros for defining routes in a router.

  ## HTTP Method Macros

  ### get/3
  Defines a GET route.

      get "/users", UserController, :index
      get "/users/:id", UserController, :show

  ### post/3
  Defines a POST route.

      post "/users", UserController, :create

  ### put/3
  Defines a PUT route.

      put "/users/:id", UserController, :update

  ### delete/3
  Defines a DELETE route.

      delete "/users/:id", UserController, :delete

  ### patch/3
  Defines a PATCH route.

      patch "/users/:id", UserController, :partial_update

  ### options/3
  Defines an OPTIONS route.

      options "/api/users", MyController, :options

  ### head/3
  Defines a HEAD route.

      head "/users", MyController, :head

  ## Inline Handlers

  You can also define inline handlers using a block:

      get "/hello" do
        json(conn, %{message: "Hello!"})
      end

  ## Plug Pipeline

  Add plugs to the pipeline:

      plug(Hibana.Plugins.BodyParser)
      plug(Hibana.Plugins.Logger)
      plug(Hibana.Plugins.Session)

  ## Complete Example

      defmodule MyApp.Router do
        use Hibana.Router.DSL

        plug(Hibana.Plugins.BodyParser)
        plug(Hibana.Plugins.Logger)

        get "/", PageController, :index
        get "/users", UserController, :index
        post "/users", UserController, :create
        get "/users/:id", UserController, :show
        put "/users/:id", UserController, :update
        delete "/users/:id", UserController, :delete

        get "/hello" do
          json(conn, %{message: "Hello!"})
        end
      end
  """

  defmacro __using__(_opts) do
    quote do
      import Plug.Conn
      import Hibana.Controller
      import Hibana.Router.DSL
      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Hibana.Router.DSL
    end
  end

  defmacro get(path, do: block) do
    quote do
      @routes {unquote(:get), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro get(path, handler, action) do
    quote do
      @routes {unquote(:get), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro post(path, do: block) do
    quote do
      @routes {unquote(:post), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro post(path, handler, action) do
    quote do
      @routes {unquote(:post), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro put(path, do: block) do
    quote do
      @routes {unquote(:put), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro put(path, handler, action) do
    quote do
      @routes {unquote(:put), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro delete(path, do: block) do
    quote do
      @routes {unquote(:delete), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro delete(path, handler, action) do
    quote do
      @routes {unquote(:delete), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro patch(path, do: block) do
    quote do
      @routes {unquote(:patch), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro patch(path, handler, action) do
    quote do
      @routes {unquote(:patch), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro options(path, do: block) do
    quote do
      @routes {unquote(:options), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro options(path, handler, action) do
    quote do
      @routes {unquote(:options), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro head(path, do: block) do
    quote do
      @routes {unquote(:head), unquote(path), fn conn -> unquote(block) end, nil}
    end
  end

  defmacro head(path, handler, action) do
    quote do
      @routes {unquote(:head), unquote(path), unquote(handler), unquote(action)}
    end
  end

  defmacro plug(plug_module, opts \\ []) do
    quote do
      @plugs {unquote(plug_module), unquote(opts)}
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def routes, do: @routes |> Enum.reverse()
      def plugs, do: @plugs |> Enum.reverse()

      @behaviour Plug

      def init(opts), do: opts

      def call(conn, _opts) do
        Hibana.Router.call(conn, %{
          routes: routes(),
          plugs: plugs()
        })
      end
    end
  end
end
