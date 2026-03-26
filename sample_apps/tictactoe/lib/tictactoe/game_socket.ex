defmodule TicTacToe.GameSocket do
  use Hibana.WebSocket

  def init(conn, opts) do
    game_id = opts[:game_id] || conn.params["id"]
    {:ok, conn, %{game_id: game_id}}
  end

  def handle_connect(_info, state) do
    if state.game_id && TicTacToe.GameServer.alive?(state.game_id) do
      TicTacToe.GameServer.subscribe(state.game_id, self())

      case TicTacToe.GameServer.get_state(state.game_id) do
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
      {:ok, %{"action" => "move", "position" => position, "player" => player}} ->
        pos =
          cond do
            is_integer(position) -> position
            is_binary(position) ->
              case Integer.parse(position) do
                {n, _} -> n
                :error -> nil
              end
            true -> nil
          end

        if is_nil(pos) do
          reply = Jason.encode!(%{type: "error", message: "Invalid position value"})
          {:reply, {:text, reply}, state}
        else if state.game_id && TicTacToe.GameServer.alive?(state.game_id) do
          case TicTacToe.GameServer.make_move(state.game_id, pos, player) do
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
        end

      {:ok, %{"action" => "get_state"}} ->
        if state.game_id && TicTacToe.GameServer.alive?(state.game_id) do
          {:ok, game_state} = TicTacToe.GameServer.get_state(state.game_id)
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
