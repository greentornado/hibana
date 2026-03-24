# `Hibana.CompiledRouter`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/compiled_router.ex#L1)

High-performance compiled router that generates pattern-match function clauses at compile time.

Routes are compiled into BEAM pattern matching, giving O(1) dispatch performance
regardless of the number of routes.

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

Routes are compiled into pattern-match clauses like:

    def match("GET", ["users", id]) -> {:ok, UserController, :show, %{"id" => id}}

This gives BEAM-native performance — the Erlang VM's pattern matching engine
handles dispatch with no list iteration or string comparison loops.

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
