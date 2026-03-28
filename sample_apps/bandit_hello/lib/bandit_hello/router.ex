defmodule BanditHello.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", BanditHello.PageController, :index
  get "/hello/:name", BanditHello.PageController, :hello
end
