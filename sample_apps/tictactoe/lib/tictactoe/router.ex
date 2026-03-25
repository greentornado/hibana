defmodule TicTacToe.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.CORS
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.Static, at: "/static", from: "priv/static"

  get("/", TicTacToe.GameController, :home)
  post("/games", TicTacToe.GameController, :create)
  get("/games/:id", TicTacToe.GameController, :show)
  post("/games/:id/move", TicTacToe.GameController, :move)
  get("/games/:id/ws", TicTacToe.GameController, :websocket)
end
