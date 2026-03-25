defmodule TicTacToe.GameServer do
  @moduledoc """
  GenServer managing the state of a single tic-tac-toe game.
  """

  use GenServer

  @inactivity_timeout 300_000

  # --- Client API ---

  def start_link({game_id, mode}) do
    GenServer.start_link(__MODULE__, {game_id, mode}, name: via(game_id))
  end

  def get_state(game_id) do
    GenServer.call(via(game_id), :get_state)
  end

  def make_move(game_id, position, player) do
    GenServer.call(via(game_id), {:move, position, player})
  end

  def subscribe(game_id, pid) do
    GenServer.cast(via(game_id), {:subscribe, pid})
  end

  def alive?(game_id) do
    case Registry.lookup(TicTacToe.GameRegistry, game_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp via(game_id) do
    {:via, Registry, {TicTacToe.GameRegistry, game_id}}
  end

  # --- Server Callbacks ---

  @impl true
  def init({game_id, mode}) do
    state = %{
      id: game_id,
      board: List.duplicate(nil, 9),
      current_player: "X",
      mode: mode,
      status: :playing,
      winner: nil,
      subscribers: [],
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    {:ok, state, @inactivity_timeout}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, public_state(state)}, state, @inactivity_timeout}
  end

  @impl true
  def handle_call({:move, position, player}, _from, state) do
    cond do
      state.status != :playing ->
        {:reply, {:error, "Game is over"}, state, @inactivity_timeout}

      player != state.current_player ->
        {:reply, {:error, "Not your turn. Current player: #{state.current_player}"}, state, @inactivity_timeout}

      position < 0 or position > 8 ->
        {:reply, {:error, "Invalid position. Must be 0-8"}, state, @inactivity_timeout}

      Enum.at(state.board, position) != nil ->
        {:reply, {:error, "Position already taken"}, state, @inactivity_timeout}

      true ->
        new_board = List.replace_at(state.board, position, player)
        new_state = %{state | board: new_board}
        new_state = check_game_over(new_state)

        new_state =
          if new_state.status == :playing do
            %{new_state | current_player: next_player(player)}
          else
            new_state
          end

        broadcast(new_state)

        # If AI mode and game still playing and it's O's turn, make AI move
        new_state = maybe_ai_move(new_state)

        # Schedule shutdown if game is over
        if new_state.status in [:won, :draw] do
          Process.send_after(self(), :shutdown, 60_000)
        end

        {:reply, {:ok, public_state(new_state)}, new_state, @inactivity_timeout}
    end
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    Process.monitor(pid)
    {:noreply, %{state | subscribers: [pid | state.subscribers]}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(:timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp maybe_ai_move(state) do
    if state.mode == "ai" and state.status == :playing and state.current_player == "O" do
      case TicTacToe.AI.best_move(state.board, "O") do
        nil ->
          state

        position ->
          new_board = List.replace_at(state.board, position, "O")
          new_state = %{state | board: new_board}
          new_state = check_game_over(new_state)

          new_state =
            if new_state.status == :playing do
              %{new_state | current_player: "X"}
            else
              new_state
            end

          broadcast(new_state)
          new_state
      end
    else
      state
    end
  end

  defp check_game_over(state) do
    board = state.board

    win_lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6]
    ]

    winner =
      Enum.find_value(win_lines, fn [a, b, c] ->
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
      winner != nil ->
        %{state | status: :won, winner: winner}

      Enum.all?(board, &(&1 != nil)) ->
        %{state | status: :draw}

      true ->
        state
    end
  end

  defp next_player("X"), do: "O"
  defp next_player("O"), do: "X"

  defp broadcast(state) do
    msg = {:game_update, public_state(state)}

    Enum.each(state.subscribers, fn pid ->
      send(pid, msg)
    end)
  end

  defp public_state(state) do
    %{
      id: state.id,
      board: state.board,
      current_player: state.current_player,
      mode: state.mode,
      status: state.status,
      winner: state.winner,
      created_at: state.created_at
    }
  end
end
