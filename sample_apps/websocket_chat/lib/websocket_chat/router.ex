defmodule WebsocketChat.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)

  get("/", WebsocketChat.PageController, :index)
end
