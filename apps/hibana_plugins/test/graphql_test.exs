defmodule Hibana.Plugins.GraphQLTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.GraphQL

  describe "init/1" do
    test "sets default options" do
      opts = GraphQL.init([])
      assert opts.schema == nil
      assert opts.playground == false
      assert opts.json_opts == []
    end

    test "allows custom options" do
      opts =
        GraphQL.init(
          schema: MyApp.Schema,
          playground: true,
          json_opts: [pretty: true]
        )

      assert opts.schema == MyApp.Schema
      assert opts.playground == true
      assert opts.json_opts == [pretty: true]
    end
  end

  describe "call/2" do
    test "returns conn for non-graphql path" do
      conn = Plug.Test.conn(:get, "/api/users")
      opts = %{schema: nil, playground: false, json_opts: []}
      result = GraphQL.call(conn, opts)
      assert result == conn
    end

    test "handles GET to playground when enabled" do
      conn = Plug.Test.conn(:get, "/graphql")
      opts = %{schema: nil, playground: true, json_opts: []}
      conn = GraphQL.call(conn, opts)
      assert conn.status == 200
    end

    test "handles GET schema request" do
      conn = Plug.Test.conn(:get, "/graphql")
      opts = %{schema: MyApp.Schema, playground: false, json_opts: []}
      conn = GraphQL.call(conn, opts)
      assert conn.status == 200
    end

    test "handles POST with valid GraphQL query" do
      body = Jason.encode!(%{query: "{ users { id } }"})

      conn =
        Plug.Test.conn(:post, "/graphql", body)
        |> Plug.Conn.put_req_header("content-type", "application/json")

      conn = Map.put(conn, :body_buffer, body)

      opts = %{schema: MyApp.Schema, playground: false, json_opts: []}
      conn = GraphQL.call(conn, opts)
      assert conn.status == 200
    end

    test "handles POST with invalid JSON" do
      conn = Plug.Test.conn(:post, "/graphql", "invalid json")
      conn = Map.put(conn, :body_buffer, "invalid json")

      opts = %{schema: nil, playground: false, json_opts: []}
      conn = GraphQL.call(conn, opts)
      assert conn.status == 400
    end

    test "handles POST with missing query" do
      body = Jason.encode!(%{no_query: true})
      conn = Plug.Test.conn(:post, "/graphql", body)
      conn = Map.put(conn, :body_buffer, body)

      opts = %{schema: nil, playground: false, json_opts: []}
      conn = GraphQL.call(conn, opts)
      assert conn.status == 400
    end
  end

  describe "execute/3" do
    test "executes query against schema" do
      result = GraphQL.execute(MyApp.Schema, "{ users { id } }")
      assert is_map(result)
    end

    test "executes with variables" do
      result = GraphQL.execute(MyApp.Schema, "{ user(id: $id) }", %{"id" => 1})
      assert is_map(result)
    end

    test "executes with operation name" do
      result = GraphQL.execute(MyApp.Schema, "query GetUser { users { id } }", %{}, "GetUser")
      assert is_map(result)
    end
  end
end
