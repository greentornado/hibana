# `Hibana.Plugins.GraphQL`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/graphql.ex#L1)

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

    curl -X POST http://localhost:4000/graphql       -H "Content-Type: application/json"       -d '{"query": "{ users { id name } }"}'

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

# `before_send`

# `execute`

Execute a GraphQL query against a schema.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
