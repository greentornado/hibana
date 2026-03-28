defmodule StreamingServer.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", StreamingServer.PageController, :index
  get "/hello/:name", StreamingServer.PageController, :hello
end
