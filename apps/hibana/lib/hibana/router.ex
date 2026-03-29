defmodule Hibana.Router do
  @moduledoc """
  Router module for handling HTTP requests with pattern matching.

  This module implements the `Plug` behaviour and provides runtime route
  matching. Routes are matched sequentially against the request method and
  path. For O(1) compiled routing, see `Hibana.CompiledRouter`.

  ## Usage

      defmodule MyApp.Router do
        use Hibana.Router.DSL

        plug Hibana.Plugins.BodyParser
        plug Hibana.Plugins.Logger

        get "/users", MyApp.UserController, :index
        post "/users", MyApp.UserController, :create
        get "/users/:id", MyApp.UserController, :show
        put "/users/:id", MyApp.UserController, :update
        delete "/users/:id", MyApp.UserController, :delete
      end

  ## Route Matching

  Routes are matched using pattern matching on the path segments:

  - **Static paths**: `/users` matches exactly
  - **Parameter paths**: `/users/:id` captures the segment as a param
  - **Wildcard paths**: `/files/*path` captures the rest of the path

  ## DSL Macros

  The `Hibana.Router.DSL` module provides route definition macros:

  | Macro | HTTP Method |
  |-------|-------------|
  | `get/3` | GET |
  | `post/3` | POST |
  | `put/3` | PUT |
  | `delete/3` | DELETE |
  | `patch/3` | PATCH |
  | `options/3` | OPTIONS |
  | `head/3` | HEAD |

  Plus `plug/1` and `plug/2` to add plugs to the request pipeline.

  ## Plug Pipeline

  Plugs registered with `plug/1` run before route matching. If any plug
  halts the connection, route matching is skipped.
  """

  @behaviour Plug

  import Plug.Conn

  @doc """
  Initializes the router with routes and plugs from the given options.

  ## Parameters

    - `opts` - Keyword list with `:routes` (list of route tuples) and `:plugs` (list of plug modules)

  ## Returns

  A map with `:routes` and `:plugs` keys.

  ## Examples

      ```elixir
      Hibana.Router.init(routes: [{:get, "/", MyController, :index}], plugs: [])
      # => %{routes: [...], plugs: []}
      ```
  """
  def init(opts) do
    %{
      routes: Keyword.get(opts, :routes, []),
      plugs: Keyword.get(opts, :plugs, [])
    }
  end

  @doc """
  Processes a request through the plug pipeline and matches it against registered routes.

  First runs all registered plugs in order. If the connection is not halted,
  attempts to match the request method and path against the route list.
  Returns a 404 response if no route matches.

  ## Parameters

    - `conn` - The `Plug.Conn` struct
    - `opts` - A map with `:routes` and `:plugs` (from `init/1`)

  ## Returns

  The connection after processing.
  """
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
    try do
      apply(handler, action, [conn])
    rescue
      error ->
        require Logger
        Logger.error("Controller error in #{inspect(handler)}.#{action}: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          500,
          Jason.encode!(%{error: "Internal Server Error", message: "Controller execution failed"})
        )
    end
  end

  defp invoke_handler(conn, handler, _action, _verb) when is_function(handler) do
    try do
      handler.(conn)
    rescue
      error ->
        require Logger
        Logger.error("Handler function error: #{inspect(error)}")

        conn
        |> put_resp_content_type("application/json")
        |> send_resp(
          500,
          Jason.encode!(%{error: "Internal Server Error", message: "Handler execution failed"})
        )
    end
  end

  defp send_404(conn) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
  end
end
