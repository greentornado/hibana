defmodule RoutingBenchmark.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/", RoutingBenchmark.PageController, :index
  get "/hello/:name", RoutingBenchmark.PageController, :hello
end
