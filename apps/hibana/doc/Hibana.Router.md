# `Hibana.Router`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/router.ex#L1)

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

# `call`

Process a request through the plug pipeline and match it against registered routes.

# `init`

Initialize the router with routes and plugs from the given options.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
