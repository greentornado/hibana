defmodule DrawingBoard.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  # HTML pages
  get("/", DrawingBoard.PageController, :index)
  get("/board/:id", DrawingBoard.PageController, :board)

  # API endpoints
  get("/api/boards", DrawingBoard.ApiController, :list_boards)
  post("/api/boards", DrawingBoard.ApiController, :create_board)

  # Health check
  get("/health", DrawingBoard.ApiController, :health)

  # WebSocket upgrade
  get("/ws/board/:id", DrawingBoard.ApiController, :ws_upgrade)
end
