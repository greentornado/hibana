defmodule LiveviewCounter.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get("/", LiveviewCounter.PageController, :index)
  get("/live/counter", LiveviewCounter.CounterSocket, :upgrade)
end
