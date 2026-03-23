defmodule Chess.GameManager do
  @moduledoc """
  Manages chess game lifecycle using DynamicSupervisor.
  """

  def create_game do
    game_id = generate_id()

    case DynamicSupervisor.start_child(Chess.GameSupervisor, {Chess.GameServer, game_id}) do
      {:ok, _pid} -> {:ok, game_id}
      {:error, reason} -> {:error, reason}
    end
  end

  def list_games do
    DynamicSupervisor.which_children(Chess.GameSupervisor)
    |> Enum.map(fn {_, pid, _, _} ->
      case Registry.keys(Chess.GameRegistry, pid) do
        [game_id] ->
          case Chess.GameServer.get_state(game_id) do
            {:ok, state} -> %{id: state.id, turn: state.turn, status: state.status, moves_count: length(state.moves)}
            _ -> nil
          end

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.hex_encode32(case: :lower, padding: false)
  end
end
