defmodule Chess.GameSocket do
  use Hibana.WebSocket

  def init(conn, opts) do
    game_id = opts[:game_id] || conn.params["id"]
    {:ok, conn, %{game_id: game_id}}
  end

  def handle_connect(_info, state) do
    # Subscribe to game updates
    if state.game_id && Chess.GameServer.alive?(state.game_id) do
      Chess.GameServer.subscribe(state.game_id, self())

      case Chess.GameServer.get_state(state.game_id) do
        {:ok, game_state} ->
          {:ok, Map.put(state, :last_state, game_state)}

        _ ->
          {:ok, state}
      end
    else
      {:ok, state}
    end
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, %{"action" => "move", "from" => from, "to" => to}} ->
        if state.game_id && Chess.GameServer.alive?(state.game_id) do
          case Chess.GameServer.make_move(state.game_id, from, to) do
            {:ok, game_state} ->
              reply = Jason.encode!(%{type: "move_accepted", game: game_state})
              {:reply, {:text, reply}, state}

            {:error, reason} ->
              reply = Jason.encode!(%{type: "error", message: reason})
              {:reply, {:text, reply}, state}
          end
        else
          reply = Jason.encode!(%{type: "error", message: "Game not found"})
          {:reply, {:text, reply}, state}
        end

      {:ok, %{"action" => "get_state"}} ->
        if state.game_id && Chess.GameServer.alive?(state.game_id) do
          {:ok, game_state} = Chess.GameServer.get_state(state.game_id)
          reply = Jason.encode!(%{type: "state", game: game_state})
          {:reply, {:text, reply}, state}
        else
          reply = Jason.encode!(%{type: "error", message: "Game not found"})
          {:reply, {:text, reply}, state}
        end

      _ ->
        reply = Jason.encode!(%{type: "error", message: "Invalid message format"})
        {:reply, {:text, reply}, state}
    end
  end

  def handle_info({:game_update, game_state}, state) do
    msg = Jason.encode!(%{type: "game_update", game: game_state})
    {:push, {:text, msg}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end
end
