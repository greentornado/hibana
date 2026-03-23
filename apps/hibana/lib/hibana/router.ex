defmodule Hibana.Router do
  @moduledoc """
  Router module for handling HTTP requests with pattern matching.

  ## Usage

      defmodule MyApp.Router do
        use Hibana.Router.DSL

        plug(Hibana.Plugins.BodyParser)
        plug(Hibana.Plugins.Logger)

        get("/users", MyApp.UserController, :index)
        post("/users", MyApp.UserController, :create)
        get("/users/:id", MyApp.UserController, :show)
        put("/users/:id", MyApp.UserController, :update)
        delete("/users/:id", MyApp.UserController, :delete)
      end

  ## Route Matching

  Routes are matched using pattern matching on the path:

  - Static paths: `/users`
  - Parameter paths: `/users/:id`
  - Wildcard paths: `/files/*path`

  ## DSL Macros

  The `Hibana.Router.DSL` module provides:

  - `get/3` - GET requests
  - `post/3` - POST requests
  - `put/3` - PUT requests
  - `delete/3` - DELETE requests
  - `patch/3` - PATCH requests
  - `options/3` - OPTIONS requests
  - `head/3` - HEAD requests

  - `plug/1` - Add a plug to the pipeline
  """

  @behaviour Plug

  import Plug.Conn

  @doc "Initialize the router with routes and plugs from the given options."
  def init(opts) do
    %{
      routes: Keyword.get(opts, :routes, []),
      plugs: Keyword.get(opts, :plugs, [])
    }
  end

  @doc "Process a request through the plug pipeline and match it against registered routes."
  def call(conn, %{routes: routes, plugs: plugs}) do
    conn =
      Enum.reduce(plugs, conn, fn plug, acc ->
        if acc.halted do
          acc
        else
          case plug do
            {module, opts} -> module.call(acc, module.init(opts))
            module when is_atom(module) -> module.call(acc, module.init([]))
          end
        end
      end)

    if conn.halted do
      conn
    else
      method = conn.method
      path = conn.path_info
      match_route(conn, method, path, routes)
    end
  end

  defp match_route(conn, _method, _path, []) do
    send_404(conn)
  end

  defp match_route(conn, method, path, [{verb, path_pattern, handler, action} | rest]) do
    verb_str = verb |> to_string() |> String.upcase()

    if verb_str == method do
      case match_path(path, path_pattern) do
        {:ok, params} ->
          conn = %{conn | params: Map.merge(conn.params, params)}
          invoke_handler(conn, handler, action, verb)

        :nomatch ->
          match_route(conn, method, path, rest)
      end
    else
      match_route(conn, method, path, rest)
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
  defp do_match([], ["*" <> _param | _], params), do: {:ok, params}
  defp do_match([h | t1], [h | t2], params), do: do_match(t1, t2, params)

  defp do_match([h | t1], [":" <> param | t2], params) when is_binary(h),
    do: do_match(t1, t2, Map.put(params, param, h))

  defp do_match(rest, ["*" <> param | _], params) do
    {:ok, Map.put(params, param, Enum.join(rest, "/"))}
  end

  defp do_match(_, _, _), do: :nomatch

  defp invoke_handler(conn, handler, action, _verb) when is_atom(handler) do
    apply(handler, action, [conn])
  end

  defp invoke_handler(conn, handler, _action, _verb) when is_function(handler) do
    handler.(conn)
  end

  defp send_404(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
  end
end
