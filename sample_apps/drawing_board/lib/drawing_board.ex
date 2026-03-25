defmodule DrawingBoard do
  use Application

  @impl true
  def start(_type, _args) do
    # Start pg scope for WebSocket broadcasting
    :pg.start(:drawing_board_pg)

    children = [
      DrawingBoard.BoardStore,
      DrawingBoard.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DrawingBoard.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
