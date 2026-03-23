defmodule LiveviewCounter.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)

  get("/", LiveviewCounter.PageController, :index)
end
