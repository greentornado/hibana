defmodule Hibana.CompiledRouter do
  @moduledoc """
  High-performance compiled router that generates pattern-match function clauses at compile time.

  Routes are compiled into BEAM pattern matching, giving O(1) dispatch performance
  regardless of the number of routes. This is the recommended router for production
  applications.

  ## Features

  - **O(1) dispatch** via Erlang VM native pattern matching
  - Same DSL as `Hibana.Router.DSL` (`get/3`, `post/3`, etc.)
  - Inline handler support with `do:` blocks
  - Plug pipeline support
  - Compile-time route validation

  ## Usage

      defmodule MyApp.Router do
        use Hibana.CompiledRouter

        plug Hibana.Plugins.Logger
        plug Hibana.Plugins.BodyParser

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

  ## How It Works

  At compile time, routes are transformed into pattern-match function clauses:

      defp do_match("GET", ["users", id]) do
        {:ok, UserController, :show, %{"id" => id}}
      end

  The Erlang VM's pattern matching engine handles dispatch with no list iteration
  or string comparison loops, giving constant-time O(1) performance regardless of
  the number of routes.

  ## Route Macros

  | Macro | HTTP Method |
  |-------|-------------|
  | `get/3` | GET |
  | `post/3` | POST |
  | `put/3` | PUT |
  | `delete/3` | DELETE |
  | `patch/3` | PATCH |
  | `options/3` | OPTIONS |
  | `head/3` | HEAD |

  Plus `plug/1` and `plug/2` for middleware.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour Plug
      import Plug.Conn
      import Hibana.Controller

      import Hibana.CompiledRouter,
        only: [
          get: 2,
          get: 3,
          post: 2,
          post: 3,
          put: 2,
          put: 3,
          delete: 2,
          delete: 3,
          patch: 2,
          patch: 3,
          options: 2,
          options: 3,
          head: 2,
          head: 3,
          plug: 1,
          plug: 2
        ]

      Module.register_attribute(__MODULE__, :routes, accumulate: true)
      Module.register_attribute(__MODULE__, :plugs, accumulate: true)
      @before_compile Hibana.CompiledRouter
    end
  end

  # Route macros - same as DSL but for compiled router
  for method <- [:get, :post, :put, :delete, :patch, :options, :head] do
    defmacro unquote(method)(path, do: block) do
      method = unquote(method)

      quote do
        @routes {unquote(method), unquote(path), {:inline, unquote(Macro.escape(block))}, nil}
      end
    end

    defmacro unquote(method)(path, handler, action) do
      method = unquote(method)

      quote do
        @routes {unquote(method), unquote(path), unquote(handler), unquote(action)}
      end
    end
  end

  defmacro plug(plug_module, opts \\ []) do
    quote do
      @plugs {unquote(plug_module), unquote(opts)}
    end
  end

  defmacro __before_compile__(env) do
    routes = Module.get_attribute(env.module, :routes) |> Enum.reverse()
    plugs = Module.get_attribute(env.module, :plugs) |> Enum.reverse()

    # Generate match clauses for each route
    {match_clauses, inline_fns} =
      Enum.map_reduce(routes, [], fn {method, path, handler, action}, acc ->
        method_str = method |> to_string() |> String.upcase()
        path_parts = String.split(path, "/", trim: true)

        # Build pattern for path segments
        {patterns, params} = build_match_pattern(path_parts)

        case handler do
          {:inline, block} ->
            fn_name = :"__inline_handler_#{:erlang.phash2({method, path})}__"

            inline_fn =
              quote do
                @doc false
                def unquote(fn_name)(var!(conn)) do
                  unquote(block)
                end
              end

            clause =
              quote do
                defp do_match(unquote(method_str), unquote(patterns)) do
                  {:ok, {:inline_fn, unquote(fn_name)}, nil, unquote(params)}
                end
              end

            {clause, [inline_fn | acc]}

          _ ->
            clause =
              quote do
                defp do_match(unquote(method_str), unquote(patterns)) do
                  {:ok, unquote(handler), unquote(action), unquote(params)}
                end
              end

            {clause, acc}
        end
      end)

    # Build plug pipeline
    plug_pipeline = build_plug_pipeline(plugs)

    quote do
      def init(opts), do: opts

      def call(var!(conn), _opts) do
        var!(conn) = unquote(plug_pipeline)

        if var!(conn).halted do
          var!(conn)
        else
          case do_match(var!(conn).method, var!(conn).path_info) do
            {:ok, handler, action, params} ->
              var!(conn) = %{var!(conn) | params: Map.merge(var!(conn).params || %{}, params)}
              invoke_handler(var!(conn), handler, action)

            :nomatch ->
              var!(conn)
              |> put_resp_content_type("text/plain")
              |> send_resp(404, "Not Found")
          end
        end
      end

      unquote_splicing(match_clauses)
      unquote_splicing(inline_fns)

      defp do_match(_, _), do: :nomatch

      defp invoke_handler(conn, handler, action) when is_atom(handler) do
        apply(handler, action, [conn])
      end

      defp invoke_handler(conn, {:inline_fn, fn_name}, _action) do
        apply(__MODULE__, fn_name, [conn])
      end

      defp invoke_handler(conn, handler, _action) when is_function(handler) do
        handler.(conn)
      end

      def routes do
        unquote(
          routes
          |> Enum.map(fn {method, path, handler, action} ->
            handler_info =
              case handler do
                {:inline, _} -> :inline
                h when is_atom(h) -> h
                _ -> :inline
              end

            {method, path, handler_info, action}
          end)
          |> Macro.escape()
        )
      end
    end
  end

  @doc false
  def build_match_pattern(path_parts) do
    build_match_pattern(path_parts, [], [])
  end

  defp build_match_pattern([], patterns_acc, params_acc) do
    patterns_acc = Enum.reverse(patterns_acc)

    params_map =
      Enum.reduce(params_acc, {:%{}, [], []}, fn {key, var}, {:%{}, meta, pairs} ->
        {:%{}, meta, [{key, var} | pairs]}
      end)

    {patterns_acc, params_map}
  end

  # Handle wildcard at the end of path - captures all remaining segments as a list
  defp build_match_pattern(["*" <> param], patterns_acc, params_acc) do
    var = Macro.var(String.to_atom("path_rest_#{param}"), nil)

    # Create ["prefix1", "prefix2" | rest] pattern if there are previous segments
    # or just `rest` if this is the only segment
    final_pattern =
      case patterns_acc do
        # Just the wildcard: match any path
        [] ->
          var

        acc ->
          # Reverse and build [seg1, seg2 | rest] pattern
          base = Enum.reverse(acc)
          build_cons_pattern(base, var)
      end

    new_params = [
      {param,
       quote do
         Path.join(unquote(var))
       end}
      | params_acc
    ]

    build_match_pattern([], [final_pattern], new_params)
  end

  # Handle regular wildcard (not at end - treat as single segment)
  defp build_match_pattern(["*" <> param | rest], patterns_acc, params_acc) do
    var = Macro.var(String.to_atom("path_param_#{param}"), nil)
    build_match_pattern(rest, [var | patterns_acc], [{param, var} | params_acc])
  end

  # Handle named parameter
  defp build_match_pattern([":" <> param | rest], patterns_acc, params_acc) do
    var = Macro.var(String.to_atom("path_param_#{param}"), nil)
    build_match_pattern(rest, [var | patterns_acc], [{param, var} | params_acc])
  end

  # Handle static segment
  defp build_match_pattern([segment | rest], patterns_acc, params_acc) do
    build_match_pattern(rest, [segment | patterns_acc], params_acc)
  end

  defp build_cons_pattern([last], rest_var) do
    quote do
      [unquote(last) | unquote(rest_var)]
    end
  end

  defp build_cons_pattern([head | tail], rest_var) do
    inner = build_cons_pattern(tail, rest_var)

    quote do
      [unquote(head) | unquote(inner)]
    end
  end

  @doc false
  def build_plug_pipeline(plugs) do
    Enum.reduce(Enum.reverse(plugs), Macro.var(:conn, nil), fn {mod, opts}, acc ->
      quote do
        conn = unquote(acc)

        if conn.halted do
          conn
        else
          unquote(mod).call(conn, unquote(mod).init(unquote(opts)))
        end
      end
    end)
  end
end
