defmodule DrawingBoard do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{id: :pg_scope, start: {:pg, :start_link, [:drawing_board_pg]}},
      DrawingBoard.BoardStore,
      DrawingBoard.Endpoint
    ]

    opts = [strategy: :one_for_one, name: DrawingBoard.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
