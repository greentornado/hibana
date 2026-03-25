defmodule Chess.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.CORS
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.BodyParser

  post("/games", Chess.GameController, :create)
  get("/games", Chess.GameController, :index)
  get("/games/:id", Chess.GameController, :show)
  post("/games/:id/move", Chess.GameController, :move)
  get("/games/:id/ws", Chess.GameController, :websocket)
end
