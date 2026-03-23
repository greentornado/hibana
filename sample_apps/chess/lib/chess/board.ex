defmodule Chess.Board do
  @moduledoc """
  Chess board representation and basic move validation.

  Board is a map with keys like "a1" through "h8".
  Pieces are represented as two-character strings:
  - First char: color ("w" or "b")
  - Second char: piece type ("P"awn, "R"ook, "N"ight, "B"ishop, "Q"ueen, "K"ing)
  """

  @files ~w(a b c d e f g h)
  @ranks ~w(1 2 3 4 5 6 7 8)

  def initial_board do
    %{
      # White pieces
      "a1" => "wR", "b1" => "wN", "c1" => "wB", "d1" => "wQ",
      "e1" => "wK", "f1" => "wB", "g1" => "wN", "h1" => "wR",
      "a2" => "wP", "b2" => "wP", "c2" => "wP", "d2" => "wP",
      "e2" => "wP", "f2" => "wP", "g2" => "wP", "h2" => "wP",
      # Black pieces
      "a7" => "bP", "b7" => "bP", "c7" => "bP", "d7" => "bP",
      "e7" => "bP", "f7" => "bP", "g7" => "bP", "h7" => "bP",
      "a8" => "bR", "b8" => "bN", "c8" => "bB", "d8" => "bQ",
      "e8" => "bK", "f8" => "bB", "g8" => "bN", "h8" => "bR"
    }
  end

  @doc "Validate and execute a move. Returns {:ok, new_board} or {:error, reason}."
  def make_move(board, from, to, turn) do
    with :ok <- validate_square(from),
         :ok <- validate_square(to),
         {:ok, piece} <- get_piece(board, from),
         :ok <- validate_color(piece, turn),
         :ok <- validate_destination(board, to, turn),
         :ok <- validate_piece_movement(piece, from, to, board) do
      new_board =
        board
        |> Map.delete(from)
        |> Map.put(to, piece)

      {:ok, new_board}
    end
  end

  @doc "Convert board to an 8x8 array for JSON representation."
  def to_array(board) do
    for rank <- Enum.reverse(@ranks) do
      for file <- @files do
        Map.get(board, file <> rank)
      end
    end
  end

  defp validate_square(square) do
    if String.length(square) == 2 do
      file = String.at(square, 0)
      rank = String.at(square, 1)

      if file in @files and rank in @ranks do
        :ok
      else
        {:error, "Invalid square: #{square}"}
      end
    else
      {:error, "Invalid square: #{square}"}
    end
  end

  defp get_piece(board, square) do
    case Map.get(board, square) do
      nil -> {:error, "No piece at #{square}"}
      piece -> {:ok, piece}
    end
  end

  defp validate_color(piece, turn) do
    color = String.at(piece, 0)
    expected = if turn == :white, do: "w", else: "b"

    if color == expected do
      :ok
    else
      {:error, "Not your turn"}
    end
  end

  defp validate_destination(board, to, turn) do
    case Map.get(board, to) do
      nil ->
        :ok

      piece ->
        dest_color = String.at(piece, 0)
        own_color = if turn == :white, do: "w", else: "b"

        if dest_color == own_color do
          {:error, "Cannot capture your own piece"}
        else
          :ok
        end
    end
  end

  defp validate_piece_movement(piece, from, to, board) do
    piece_type = String.at(piece, 1)
    color = String.at(piece, 0)
    {from_file, from_rank} = parse_square(from)
    {to_file, to_rank} = parse_square(to)
    df = to_file - from_file
    dr = to_rank - from_rank

    case piece_type do
      "P" -> validate_pawn(color, df, dr, from_rank, board, to)
      "R" -> validate_rook(df, dr, from, to, board)
      "B" -> validate_bishop(df, dr, from, to, board)
      "Q" -> validate_queen(df, dr, from, to, board)
      "K" -> validate_king(df, dr)
      "N" -> validate_knight(df, dr)
      _ -> {:error, "Unknown piece type"}
    end
  end

  defp parse_square(square) do
    file = String.at(square, 0)
    rank = String.at(square, 1)
    file_num = Enum.find_index(@files, &(&1 == file))
    rank_num = String.to_integer(rank)
    {file_num, rank_num}
  end

  defp square_from(file_num, rank_num) do
    Enum.at(@files, file_num) <> Integer.to_string(rank_num)
  end

  # Pawn: forward 1 (or 2 from start), diagonal capture
  defp validate_pawn(color, df, dr, from_rank, board, to) do
    direction = if color == "w", do: 1, else: -1
    start_rank = if color == "w", do: 2, else: 7

    cond do
      # Forward one square
      df == 0 and dr == direction and Map.get(board, to) == nil ->
        :ok

      # Forward two squares from starting position
      df == 0 and dr == 2 * direction and from_rank == start_rank and Map.get(board, to) == nil ->
        :ok

      # Diagonal capture
      abs(df) == 1 and dr == direction and Map.get(board, to) != nil ->
        :ok

      true ->
        {:error, "Invalid pawn move"}
    end
  end

  # Rook: straight lines
  defp validate_rook(df, dr, from, to, board) do
    if (df == 0 and dr != 0) or (dr == 0 and df != 0) do
      if path_clear?(from, to, board) do
        :ok
      else
        {:error, "Path is blocked"}
      end
    else
      {:error, "Invalid rook move"}
    end
  end

  # Bishop: diagonals
  defp validate_bishop(df, dr, from, to, board) do
    if abs(df) == abs(dr) and df != 0 do
      if path_clear?(from, to, board) do
        :ok
      else
        {:error, "Path is blocked"}
      end
    else
      {:error, "Invalid bishop move"}
    end
  end

  # Queen: straight lines or diagonals
  defp validate_queen(df, dr, from, to, board) do
    is_straight = (df == 0 and dr != 0) or (dr == 0 and df != 0)
    is_diagonal = abs(df) == abs(dr) and df != 0

    if is_straight or is_diagonal do
      if path_clear?(from, to, board) do
        :ok
      else
        {:error, "Path is blocked"}
      end
    else
      {:error, "Invalid queen move"}
    end
  end

  # King: one square in any direction
  defp validate_king(df, dr) do
    if abs(df) <= 1 and abs(dr) <= 1 and (df != 0 or dr != 0) do
      :ok
    else
      {:error, "Invalid king move"}
    end
  end

  # Knight: L-shape
  defp validate_knight(df, dr) do
    if (abs(df) == 2 and abs(dr) == 1) or (abs(df) == 1 and abs(dr) == 2) do
      :ok
    else
      {:error, "Invalid knight move"}
    end
  end

  # Check if the path between two squares is clear (for rook, bishop, queen)
  defp path_clear?(from, to, board) do
    {from_file, from_rank} = parse_square(from)
    {to_file, to_rank} = parse_square(to)

    df = sign(to_file - from_file)
    dr = sign(to_rank - from_rank)

    steps = max(abs(to_file - from_file), abs(to_rank - from_rank)) - 1

    Enum.all?(1..max(steps, 1)//1, fn i ->
      if i <= steps do
        sq = square_from(from_file + df * i, from_rank + dr * i)
        Map.get(board, sq) == nil
      else
        true
      end
    end)
  end

  defp sign(0), do: 0
  defp sign(n) when n > 0, do: 1
  defp sign(_), do: -1
end
