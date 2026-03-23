defmodule Hibana.Plugins.GraphQL do
  @moduledoc """
  GraphQL plugin for query resolution and playground.

  ## Features

  - POST /graphql - Execute GraphQL queries
  - GET /graphql - Schema introspection
  - GraphQL Playground (optional)

  ## Usage

      plug Hibana.Plugins.GraphQL,
        schema: MyApp.Schema,
        playground: true

  ## Endpoints

  ### POST /graphql
  Execute GraphQL queries:

      curl -X POST http://localhost:4000/graphql \
        -H "Content-Type: application/json" \
        -d '{"query": "{ users { id name } }"}'

  ### GET /graphql
  Schema introspection JSON:

      curl http://localhost:4000/graphql

  ### GET /graphql (with playground enabled)
  Interactive GraphQL Playground:

      http://localhost:4000/graphql

  ## Options

  - `:schema` - GraphQL schema module (required)
  - `:playground` - Enable GraphQL Playground (default: `false`)
  - `:json_opts` - Options for JSON encoding

  ## Module Functions

  ### execute/4
  Execute a GraphQL query programmatically:

      result = Hibana.Plugins.GraphQL.execute(
        schema,
        "{ users { id name } }",
        %{},
        nil
      )

  ## Request Format

      {
        "query": "query($id: ID!) { user(id: $id) { name } }",
        "variables": {"id": "123"},
        "operationName": "MyQuery"
      }
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      schema: Keyword.get(opts, :schema),
      playground: Keyword.get(opts, :playground, false),
      json_opts: Keyword.get(opts, :json_opts, [])
    }
  end

  @impl true
  def call(conn, %{schema: schema, playground: playground}) do
    case conn.path_info do
      ["graphql"] when conn.method == "GET" and playground == true ->
        playground_html(conn)

      ["graphql"] when conn.method == "POST" ->
        execute_graphql(conn, schema)

      ["graphql"] when conn.method == "GET" ->
        schema_json(conn, schema)

      _ ->
        conn
    end
  end

  defp playground_html(conn) do
    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/graphql-playground-react/build/static/css/index.css" />
      <script src="https://cdn.jsdelivr.net/npm/graphql-playground-react/build/static/js/middleware.js"></script>
    </head>
    <body>
      <div id="graphql-playground"></div>
      <script>
        window.addEventListener('load', function() {
          GraphQLPlayground.create(document.getElementById('graphql-playground'), { endpoint: '/graphql' });
        });
      </script>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
    |> halt()
  end

  defp read_full_body(conn, acc \\ "") do
    case Plug.Conn.read_body(conn) do
      {:ok, body, conn} -> {:ok, acc <> body, conn}
      {:more, partial, conn} -> read_full_body(conn, acc <> partial)
      {:error, reason} -> {:error, reason}
    end
  end

  defp execute_graphql(conn, schema) do
    case read_full_body(conn) do
      {:ok, body, conn} ->
        case Jason.decode(body) do
          {:ok, %{"query" => query} = request} ->
            variables = Map.get(request, "variables", %{})
            operation_name = Map.get(request, "operationName")

            result = resolve_query(schema, query, variables, operation_name)

            conn
            |> put_resp_content_type("application/json")
            |> send_resp(200, Jason.encode!(result))
            |> halt()

          {:ok, _} ->
            error_response(conn, "Invalid GraphQL request: missing 'query' field")

          {:error, _} ->
            error_response(conn, "Invalid JSON body")
        end

      _ ->
        error_response(conn, "Failed to read body")
    end
  end

  defp resolve_query(schema, query, variables, operation_name) do
    if schema && Code.ensure_loaded?(schema) && function_exported?(schema, :execute, 3) do
      schema.execute(query, variables, operation_name)
    else
      %{
        data: nil,
        errors: [
          %{message: "Schema resolver not configured. Provide a schema module with execute/3."}
        ]
      }
    end
  end

  defp schema_json(conn, _schema) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{data: %{__schema: %{types: []}}}))
    |> halt()
  end

  defp error_response(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(400, Jason.encode!(%{errors: [%{message: message}]}))
    |> halt()
  end

  @doc """
  Execute a GraphQL query against a schema.
  """
  def execute(schema, query, variables \\ %{}, operation_name \\ nil) do
    resolve_query(schema, query, variables, operation_name)
  end
end
