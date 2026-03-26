defmodule QuizGame.GameServer do
  @moduledoc """
  GenServer managing a single game instance. Handles player joining,
  question progression, answer scoring, and timer management.
  """

  use GenServer

  defstruct [
    :code,
    :quiz,
    :host,
    :status,
    :current_question,
    :question_start_time,
    :timer_ref,
    players: %{},
    scores: %{},
    answers: %{}
  ]

  # Client API

  def start_link({code, quiz, host}) do
    GenServer.start_link(__MODULE__, {code, quiz, host}, name: via(code))
  end

  def join(code, name) do
    GenServer.call(via(code), {:join, name})
  end

  def get_state(code) do
    GenServer.call(via(code), :get_state)
  end

  def start_game(code) do
    GenServer.call(via(code), :start_game)
  end

  def submit_answer(code, player_name, option) do
    GenServer.call(via(code), {:answer, player_name, option})
  end

  def register_player_pid(code, name, pid) do
    GenServer.cast(via(code), {:register_pid, name, pid})
  end

  def unregister_player_pid(code, name) do
    GenServer.cast(via(code), {:unregister_pid, name})
  end

  defp via(code) do
    {:via, Registry, {QuizGame.GameRegistry, code}}
  end

  # Server callbacks

  @impl true
  def init({code, quiz, host}) do
    state = %__MODULE__{
      code: code,
      quiz: quiz,
      host: host,
      status: :waiting,
      current_question: 0,
      players: %{},
      scores: %{},
      answers: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, name}, _from, state) do
    if state.status != :waiting do
      {:reply, {:error, :game_in_progress}, state}
    else if Map.has_key?(state.scores, name) do
      {:reply, {:error, :name_taken}, state}
    else
      new_scores = Map.put(state.scores, name, 0)
      state = %{state | scores: new_scores}
      player_list = Map.keys(new_scores)

      broadcast(state, %{
        type: "player_joined",
        name: name,
        players: player_list
      })

      {:reply, {:ok, player_list}, state}
    end
    end
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    reply = %{
      code: state.code,
      quiz_title: state.quiz["title"],
      host: state.host,
      status: Atom.to_string(state.status),
      players: Map.keys(state.scores),
      scores: state.scores,
      current_question: state.current_question,
      total_questions: length(state.quiz["questions"])
    }

    {:reply, {:ok, reply}, state}
  end

  @impl true
  def handle_call(:start_game, _from, state) do
    if state.status != :waiting do
      {:reply, {:error, :already_started}, state}
    else
      state = %{state | status: :playing}
      send_question(state)
      {:reply, :ok, start_timer(state)}
    end
  end

  @impl true
  def handle_call({:answer, player_name, option}, _from, state) do
    if state.status != :playing do
      {:reply, {:error, :not_playing}, state}
    else if Map.has_key?(state.answers, player_name) do
      {:reply, {:error, :already_answered}, state}
    else
      elapsed = System.monotonic_time(:millisecond) - state.question_start_time
      question = Enum.at(state.quiz["questions"], state.current_question)
      time_limit_ms = (question["time_limit"] || 15) * 1000

      points =
        if option == question["correct"] do
          # Faster answer = more points (max 100, linear decrease)
          time_fraction = max(0, 1 - elapsed / time_limit_ms)
          round(50 + 50 * time_fraction)
        else
          0
        end

      new_scores = Map.update!(state.scores, player_name, &(&1 + points))
      new_answers = Map.put(state.answers, player_name, %{option: option, points: points})
      state = %{state | scores: new_scores, answers: new_answers}

      # Check if all players answered
      all_answered = map_size(state.answers) >= map_size(state.scores)

      state =
        if all_answered do
          cancel_timer(state)
          finish_question(state)
        else
          state
        end

      {:reply, {:ok, points}, state}
    end
    end
  end

  @impl true
  def handle_cast({:register_pid, name, pid}, state) do
    Process.monitor(pid)
    players = Map.put(state.players, name, pid)
    {:noreply, %{state | players: players}}
  end

  @impl true
  def handle_cast({:unregister_pid, name}, state) do
    players = Map.delete(state.players, name)
    {:noreply, %{state | players: players}}
  end

  @impl true
  def handle_info(:time_up, state) do
    state = finish_question(state)
    {:noreply, state}
  end

  def handle_info(:send_next_question, state) do
    if state.status == :playing do
      send_question(state)
      {:noreply, start_timer(state)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove disconnected player's PID
    players = state.players
      |> Enum.reject(fn {_name, p} -> p == pid end)
      |> Map.new()
    {:noreply, %{state | players: players}}
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private helpers

  defp send_question(state) do
    question = Enum.at(state.quiz["questions"], state.current_question)
    total = length(state.quiz["questions"])

    broadcast(state, %{
      type: "question",
      index: state.current_question,
      total: total,
      text: question["text"],
      options: question["options"],
      time_limit: question["time_limit"] || 15
    })
  end

  defp finish_question(state) do
    question = Enum.at(state.quiz["questions"], state.current_question)

    broadcast(state, %{
      type: "answer_result",
      correct: question["correct"],
      scores: state.scores
    })

    next_index = state.current_question + 1
    total = length(state.quiz["questions"])

    if next_index >= total do
      # Game over
      leaderboard =
        state.scores
        |> Enum.sort_by(fn {_name, score} -> score end, :desc)
        |> Enum.map(fn {name, score} -> %{name: name, score: score} end)

      broadcast(state, %{
        type: "game_over",
        leaderboard: leaderboard
      })

      Process.send_after(self(), :shutdown, 60_000)
      %{state | status: :finished, current_question: next_index, answers: %{}, timer_ref: nil}
    else
      # Next question after a short delay
      state = %{state | current_question: next_index, answers: %{}}
      Process.send_after(self(), :send_next_question, 3000)
      %{state | timer_ref: nil}
    end
  end

  defp start_timer(state) do
    question = Enum.at(state.quiz["questions"], state.current_question)
    time_limit_ms = (question["time_limit"] || 15) * 1000
    ref = Process.send_after(self(), :time_up, time_limit_ms)
    %{state | timer_ref: ref, question_start_time: System.monotonic_time(:millisecond)}
  end

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | timer_ref: nil}
  end

  defp broadcast(state, message) do
    encoded = Jason.encode!(message)

    Enum.each(state.players, fn {_name, pid} ->
      send(pid, {:broadcast, encoded})
    end)
  end
end
