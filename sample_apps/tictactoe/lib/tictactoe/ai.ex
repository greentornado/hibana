defmodule TicTacToe.AI do
  @moduledoc """
  Minimax AI for tic-tac-toe. Plays optimally as "O" against "X".
  """

  @win_lines [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6]
  ]

  @doc "Returns the best move position (0-8) for the given player, or nil if no moves available."
  def best_move(board, player) do
    available = available_positions(board)

    if available == [] do
      nil
    else
      {position, _score} =
        available
        |> Enum.map(fn pos ->
          new_board = List.replace_at(board, pos, player)
          score = minimax(new_board, opponent(player), false, 0)
          {pos, score}
        end)
        |> Enum.max_by(fn {_pos, score} -> score end)

      position
    end
  end

  defp minimax(board, current_player, is_maximizing, depth) do
    case evaluate(board) do
      {:winner, winner} ->
        if winner == "O", do: 10 - depth, else: depth - 10

      :draw ->
        0

      :ongoing ->
        available = available_positions(board)

        if is_maximizing do
          available
          |> Enum.map(fn pos ->
            new_board = List.replace_at(board, pos, current_player)
            minimax(new_board, opponent(current_player), false, depth + 1)
          end)
          |> Enum.max(fn -> 0 end)
        else
          available
          |> Enum.map(fn pos ->
            new_board = List.replace_at(board, pos, current_player)
            minimax(new_board, opponent(current_player), true, depth + 1)
          end)
          |> Enum.min(fn -> 0 end)
        end
    end
  end

  defp evaluate(board) do
    winner =
      Enum.find_value(@win_lines, fn [a, b, c] ->
        va = Enum.at(board, a)
        vb = Enum.at(board, b)
        vc = Enum.at(board, c)

        if va != nil and va == vb and vb == vc do
          va
        else
          nil
        end
      end)

    cond do
      winner != nil -> {:winner, winner}
      Enum.all?(board, &(&1 != nil)) -> :draw
      true -> :ongoing
    end
  end

  defp available_positions(board) do
    board
    |> Enum.with_index()
    |> Enum.filter(fn {cell, _idx} -> cell == nil end)
    |> Enum.map(fn {_cell, idx} -> idx end)
  end

  defp opponent("X"), do: "O"
  defp opponent("O"), do: "X"
end
