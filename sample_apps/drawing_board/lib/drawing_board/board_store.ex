defmodule DrawingBoard.BoardStore do
  use GenServer

  @max_strokes 5000

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def create_board(name) do
    GenServer.call(__MODULE__, {:create_board, name})
  end

  def list_boards do
    GenServer.call(__MODULE__, :list_boards)
  end

  def get_board(board_id) do
    GenServer.call(__MODULE__, {:get_board, board_id})
  end

  def add_stroke(board_id, stroke) do
    GenServer.call(__MODULE__, {:add_stroke, board_id, stroke})
  end

  def clear_board(board_id) do
    GenServer.call(__MODULE__, {:clear_board, board_id})
  end

  def undo_stroke(board_id, user) do
    GenServer.call(__MODULE__, {:undo_stroke, board_id, user})
  end

  def get_strokes(board_id) do
    GenServer.call(__MODULE__, {:get_strokes, board_id})
  end

  # User tracking

  def add_user(board_id, user) do
    GenServer.call(__MODULE__, {:add_user, board_id, user})
  end

  def remove_user(board_id, user) do
    GenServer.call(__MODULE__, {:remove_user, board_id, user})
  end

  def get_users(board_id) do
    GenServer.call(__MODULE__, {:get_users, board_id})
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    boards = :ets.new(:drawing_boards, [:set, :protected, :named_table])
    users = :ets.new(:drawing_board_users, [:set, :protected, :named_table])
    {:ok, %{boards: boards, users: users}}
  end

  @impl true
  def handle_call({:create_board, name}, _from, state) do
    board_id = generate_id()
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    board = %{id: board_id, name: name, strokes: [], created_at: now}
    :ets.insert(:drawing_boards, {board_id, board})
    :ets.insert(:drawing_board_users, {board_id, []})
    {:reply, {:ok, board}, state}
  end

  def handle_call(:list_boards, _from, state) do
    boards =
      :ets.tab2list(:drawing_boards)
      |> Enum.map(fn {_id, board} ->
        user_count =
          case :ets.lookup(:drawing_board_users, board.id) do
            [{_, users}] -> length(users)
            [] -> 0
          end

        %{
          id: board.id,
          name: board.name,
          stroke_count: length(board.strokes),
          user_count: user_count,
          created_at: board.created_at
        }
      end)
      |> Enum.sort_by(& &1.created_at, :desc)

    {:reply, boards, state}
  end

  def handle_call({:get_board, board_id}, _from, state) do
    case :ets.lookup(:drawing_boards, board_id) do
      [{_, board}] -> {:reply, {:ok, board}, state}
      [] -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:add_stroke, board_id, stroke}, _from, state) do
    case :ets.lookup(:drawing_boards, board_id) do
      [{_, board}] ->
        strokes = Enum.take([stroke | board.strokes], @max_strokes)
        updated = %{board | strokes: strokes}
        :ets.insert(:drawing_boards, {board_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:clear_board, board_id}, _from, state) do
    case :ets.lookup(:drawing_boards, board_id) do
      [{_, board}] ->
        updated = %{board | strokes: []}
        :ets.insert(:drawing_boards, {board_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:undo_stroke, board_id, user}, _from, state) do
    case :ets.lookup(:drawing_boards, board_id) do
      [{_, board}] ->
        strokes = remove_last_stroke_by_user(board.strokes, user)
        updated = %{board | strokes: strokes}
        :ets.insert(:drawing_boards, {board_id, updated})
        {:reply, :ok, state}

      [] ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:get_strokes, board_id}, _from, state) do
    case :ets.lookup(:drawing_boards, board_id) do
      [{_, board}] -> {:reply, Enum.reverse(board.strokes), state}
      [] -> {:reply, [], state}
    end
  end

  def handle_call({:add_user, board_id, user}, _from, state) do
    users =
      case :ets.lookup(:drawing_board_users, board_id) do
        [{_, existing}] -> Enum.uniq([user | existing])
        [] -> [user]
      end

    :ets.insert(:drawing_board_users, {board_id, users})
    {:reply, users, state}
  end

  def handle_call({:remove_user, board_id, user}, _from, state) do
    users =
      case :ets.lookup(:drawing_board_users, board_id) do
        [{_, existing}] -> List.delete(existing, user)
        [] -> []
      end

    :ets.insert(:drawing_board_users, {board_id, users})
    {:reply, users, state}
  end

  def handle_call({:get_users, board_id}, _from, state) do
    case :ets.lookup(:drawing_board_users, board_id) do
      [{_, users}] -> {:reply, users, state}
      [] -> {:reply, [], state}
    end
  end

  # Helpers

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end

  defp remove_last_stroke_by_user(strokes, user) do
    # Strokes are stored newest-first; find and remove the first one by this user
    case Enum.split_while(strokes, fn s -> Map.get(s, :user) != user end) do
      {before, [_removed | after_removed]} -> before ++ after_removed
      {all, []} -> all
    end
  end
end
