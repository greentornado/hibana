defmodule HelloWorld.Router do
  use Hibana.Router.DSL

  get("/", HelloWorld.PageController, :index)
  get("/hello", HelloWorld.PageController, :hello)
  get("/hello/:name", HelloWorld.PageController, :hello_with_name)
end
