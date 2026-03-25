defmodule DrawingBoard.BoardSocket do
  use Hibana.WebSocket

  alias DrawingBoard.BoardStore

  @impl true
  def init(conn, opts) do
    board_id = Map.get(opts, :board_id, conn.params["id"])
    name = Map.get(opts, :name, conn.query_params["name"] || "Anonymous")

    state = %{
      board_id: board_id,
      name: name
    }

    {:ok, conn, state}
  end

  @impl true
  def handle_connect(_info, state) do
    %{board_id: board_id, name: name} = state

    # Register this process for broadcasting
    :pg.join(:drawing_board_pg, {:board, board_id}, [self()])

    # Add user and get current user list
    users = BoardStore.add_user(board_id, name)

    # Broadcast user_joined to all peers
    broadcast(board_id, %{
      type: "user_joined",
      user: name,
      users: users
    })

    # Send stroke history to this new client
    strokes = BoardStore.get_strokes(board_id)

    send(self(), {:send_history, strokes, users})

    {:ok, state}
  end

  @impl true
  def handle_disconnect(_reason, state) do
    %{board_id: board_id, name: name} = state

    # Remove from pg group
    :pg.leave(:drawing_board_pg, {:board, board_id}, [self()])

    # Remove user
    users = BoardStore.remove_user(board_id, name)

    # Broadcast user_left
    broadcast(board_id, %{
      type: "user_left",
      user: name,
      users: users
    })

    {:ok, state}
  end

  @impl true
  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, payload} ->
        handle_message(payload, state)

      {:error, _} ->
        {:ok, state}
    end
  end

  @impl true
  def handle_info({:send_history, strokes, users}, state) do
    msg = Jason.encode!(%{type: "history", strokes: strokes, users: users})
    {:push, {:text, msg}, state}
  end

  def handle_info({:broadcast, payload}, state) do
    msg = Jason.encode!(payload)
    {:push, {:text, msg}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  # Private

  defp handle_message(%{"type" => "draw"} = payload, state) do
    %{board_id: board_id, name: name} = state

    stroke = %{
      user: name,
      x1: payload["x1"],
      y1: payload["y1"],
      x2: payload["x2"],
      y2: payload["y2"],
      color: payload["color"] || "#ffffff",
      width: payload["width"] || 3
    }

    BoardStore.add_stroke(board_id, stroke)

    broadcast_others(board_id, %{
      type: "draw",
      user: name,
      x1: stroke.x1,
      y1: stroke.y1,
      x2: stroke.x2,
      y2: stroke.y2,
      color: stroke.color,
      width: stroke.width
    })

    {:ok, state}
  end

  defp handle_message(%{"type" => "clear"}, state) do
    %{board_id: board_id, name: name} = state

    BoardStore.clear_board(board_id)

    broadcast(board_id, %{
      type: "clear",
      user: name
    })

    {:ok, state}
  end

  defp handle_message(%{"type" => "undo"}, state) do
    %{board_id: board_id, name: name} = state

    BoardStore.undo_stroke(board_id, name)

    # Send full history to all clients so they can re-render
    strokes = BoardStore.get_strokes(board_id)

    broadcast(board_id, %{
      type: "history",
      strokes: strokes
    })

    {:ok, state}
  end

  defp handle_message(_payload, state) do
    {:ok, state}
  end

  defp broadcast(board_id, payload) do
    members = :pg.get_members(:drawing_board_pg, {:board, board_id})

    for pid <- members do
      send(pid, {:broadcast, payload})
    end
  end

  defp broadcast_others(board_id, payload) do
    members = :pg.get_members(:drawing_board_pg, {:board, board_id})

    for pid <- members, pid != self() do
      send(pid, {:broadcast, payload})
    end
  end
end
