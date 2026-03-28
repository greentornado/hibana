defmodule RealtimeCluster.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", RealtimeCluster.PageController, :index
  get "/hello/:name", RealtimeCluster.PageController, :hello
end
