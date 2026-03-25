defmodule Chess.GameServer do
  @moduledoc """
  GenServer managing the state of a single chess game.
  """

  use GenServer

  @inactivity_timeout 600_000

  # --- Client API ---

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via(game_id))
  end

  def get_state(game_id) do
    GenServer.call(via(game_id), :get_state)
  end

  def make_move(game_id, from, to) do
    GenServer.call(via(game_id), {:move, from, to})
  end

  def subscribe(game_id, pid) do
    GenServer.cast(via(game_id), {:subscribe, pid})
  end

  def alive?(game_id) do
    case Registry.lookup(Chess.GameRegistry, game_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp via(game_id) do
    {:via, Registry, {Chess.GameRegistry, game_id}}
  end

  # --- Server Callbacks ---

  @impl true
  def init(game_id) do
    state = %{
      id: game_id,
      board: Chess.Board.initial_board(),
      turn: :white,
      moves: [],
      status: :playing,
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
  def handle_call({:move, from, to}, _from, state) do
    if state.status != :playing do
      {:reply, {:error, "Game is over"}, state, @inactivity_timeout}
    else
      case Chess.Board.make_move(state.board, from, to, state.turn) do
        {:ok, new_board} ->
          move_record = %{
            from: from,
            to: to,
            player: state.turn,
            number: length(state.moves) + 1
          }

          next_turn = if state.turn == :white, do: :black, else: :white

          new_state = %{
            state
            | board: new_board,
              turn: next_turn,
              moves: state.moves ++ [move_record]
          }

          broadcast(new_state)
          {:reply, {:ok, public_state(new_state)}, new_state, @inactivity_timeout}

        {:error, reason} ->
          {:reply, {:error, reason}, state, @inactivity_timeout}
      end
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
  def handle_info(_msg, state) do
    {:noreply, state}
  end

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
      board_array: Chess.Board.to_array(state.board),
      turn: state.turn,
      moves: state.moves,
      status: state.status,
      created_at: state.created_at
    }
  end
end
