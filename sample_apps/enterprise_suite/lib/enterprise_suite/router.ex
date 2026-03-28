defmodule EnterpriseSuite.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", EnterpriseSuite.PageController, :index
  get "/hello/:name", EnterpriseSuite.PageController, :hello
end
