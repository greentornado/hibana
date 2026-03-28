defmodule ResilientServices.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", ResilientServices.PageController, :index
  get "/hello/:name", ResilientServices.PageController, :hello
end
