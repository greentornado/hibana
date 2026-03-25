defmodule DrawingBoard.ApiController do
  use Hibana.Controller

  alias DrawingBoard.BoardStore

  def list_boards(conn) do
    boards = BoardStore.list_boards()
    json(conn, %{boards: boards})
  end

  def create_board(conn) do
    name = Map.get(conn.body_params, "name", "Untitled Board")

    case BoardStore.create_board(name) do
      {:ok, board} ->
        conn
        |> put_status(201)
        |> json(%{board: %{id: board.id, name: board.name, created_at: board.created_at}})

      _ ->
        conn
        |> put_status(500)
        |> json(%{error: "Failed to create board"})
    end
  end

  def health(conn) do
    json(conn, %{status: "ok", app: "drawing_board", port: 4031})
  end

  def ws_upgrade(conn) do
    name = conn.query_params["name"] || "Anonymous"
    board_id = conn.params["id"]
    Hibana.WebSocket.upgrade(conn, DrawingBoard.BoardSocket, %{name: name, board_id: board_id})
  end
end
