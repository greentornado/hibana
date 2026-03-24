# `Hibana.Router.DSL`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/router/dsl.ex#L1)

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

# `delete`
*macro* 

# `delete`
*macro* 

# `get`
*macro* 

# `get`
*macro* 

# `head`
*macro* 

# `head`
*macro* 

# `options`
*macro* 

# `options`
*macro* 

# `patch`
*macro* 

# `patch`
*macro* 

# `plug`
*macro* 

# `post`
*macro* 

# `post`
*macro* 

# `put`
*macro* 

# `put`
*macro* 

---

*Consult [api-reference.md](api-reference.md) for complete listing*
