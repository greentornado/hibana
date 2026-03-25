defmodule RestApi.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger

  get("/api/users", RestApi.UserController, :index)
  get("/api/users/:id", RestApi.UserController, :show)
  post("/api/users", RestApi.UserController, :create)
  put("/api/users/:id", RestApi.UserController, :update)
  delete("/api/users/:id", RestApi.UserController, :delete)

  get("/api/posts", RestApi.PostController, :index)
  get("/api/posts/:id", RestApi.PostController, :show)
  post("/api/posts", RestApi.PostController, :create)
end
