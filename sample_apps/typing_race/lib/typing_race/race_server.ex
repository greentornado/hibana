defmodule TypingRace.RaceServer do
  use GenServer

  @timeout_ms 120_000
  @countdown_seconds 3

  # Client API

  def start_link(opts) do
    code = Keyword.fetch!(opts, :code)
    max_players = Keyword.get(opts, :max_players, 4)

    GenServer.start_link(__MODULE__, %{code: code, max_players: max_players},
      name: via(code)
    )
  end

  def via(code) do
    {:via, Registry, {TypingRace.RaceRegistry, code}}
  end

  def join(code, name) do
    GenServer.call(via(code), {:join, name})
  end

  def get_state(code) do
    GenServer.call(via(code), :get_state)
  end

  def start_race(code) do
    GenServer.call(via(code), :start_race)
  end

  def update_progress(code, name, typed, position) do
    GenServer.cast(via(code), {:progress, name, typed, position})
  end

  def player_finished(code, name, time_ms) do
    GenServer.cast(via(code), {:finished, name, time_ms})
  end

  def register_socket(code, name, pid) do
    GenServer.cast(via(code), {:register_socket, name, pid})
  end

  def unregister_socket(code, name) do
    GenServer.cast(via(code), {:unregister_socket, name})
  end

  # Server callbacks

  @impl true
  def init(%{code: code, max_players: max_players}) do
    state = %{
      code: code,
      max_players: max_players,
      status: :waiting,
      players: %{},
      sockets: %{},
      text: nil,
      started_at: nil,
      finish_order: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:join, name}, _from, state) do
    cond do
      state.status != :waiting ->
        {:reply, {:error, "Race already started"}, state}

      map_size(state.players) >= state.max_players ->
        {:reply, {:error, "Race is full"}, state}

      Map.has_key?(state.players, name) ->
        {:reply, {:error, "Name already taken"}, state}

      true ->
        player = %{name: name, percent: 0, wpm: 0, finished: false, time_ms: nil, position: nil}
        new_state = put_in(state, [:players, name], player)

        broadcast(new_state, %{
          type: "player_joined",
          name: name,
          players: format_player_list(new_state.players)
        })

        {:reply, {:ok, new_state}, new_state}
    end
  end

  def handle_call(:get_state, _from, state) do
    reply = %{
      code: state.code,
      status: state.status,
      max_players: state.max_players,
      players: format_player_list(state.players),
      text: state.text
    }

    {:reply, {:ok, reply}, state}
  end

  def handle_call(:start_race, _from, state) do
    if state.status != :waiting do
      {:reply, {:error, "Race already started"}, state}
    else
      if map_size(state.players) < 2 do
        {:reply, {:error, "Need at least 2 players"}, state}
      else
        new_state = %{state | status: :countdown}
        send(self(), {:countdown, @countdown_seconds})
        {:reply, :ok, new_state}
      end
    end
  end

  @impl true
  def handle_cast({:progress, name, typed, position}, state) do
    if state.status != :racing || !Map.has_key?(state.players, name) do
      {:noreply, state}
    else
      text = state.text
      text_length = String.length(text)
      percent = min(round(position / text_length * 100), 100)

      elapsed_ms = System.monotonic_time(:millisecond) - state.started_at
      elapsed_min = max(elapsed_ms / 60_000, 0.001)
      chars_typed = String.length(typed)
      wpm = round(chars_typed / 5 / elapsed_min)

      player = state.players[name]
      updated_player = %{player | percent: percent, wpm: wpm}
      new_state = put_in(state, [:players, name], updated_player)

      broadcast(new_state, %{
        type: "progress",
        players: format_progress(new_state.players)
      })

      {:noreply, new_state}
    end
  end

  def handle_cast({:finished, name, time_ms}, state) do
    if state.status != :racing || !Map.has_key?(state.players, name) do
      {:noreply, state}
    else
      player = state.players[name]

      if player.finished do
        {:noreply, state}
      else
        finish_order = state.finish_order + 1
        text_length = String.length(state.text)
        elapsed_min = max(time_ms / 60_000, 0.001)
        wpm = round(text_length / 5 / elapsed_min)

        updated_player = %{
          player
          | finished: true,
            time_ms: time_ms,
            position: finish_order,
            percent: 100,
            wpm: wpm
        }

        new_state = put_in(state, [:players, name], updated_player)
        new_state = %{new_state | finish_order: finish_order}

        broadcast(new_state, %{
          type: "player_finished",
          name: name,
          time_ms: time_ms,
          wpm: wpm,
          position: finish_order
        })

        all_finished = Enum.all?(new_state.players, fn {_k, p} -> p.finished end)

        if all_finished do
          end_race(new_state)
        else
          {:noreply, new_state}
        end
      end
    end
  end

  def handle_cast({:register_socket, name, pid}, state) do
    {:noreply, put_in(state, [:sockets, name], pid)}
  end

  def handle_cast({:unregister_socket, name}, state) do
    {_pid, new_sockets} = Map.pop(state.sockets, name)
    {:noreply, %{state | sockets: new_sockets}}
  end

  @impl true
  def handle_info({:countdown, 0}, state) do
    text = TypingRace.TextProvider.random_text()
    started_at = System.monotonic_time(:millisecond)

    new_state = %{state | status: :racing, text: text, started_at: started_at}

    broadcast(new_state, %{
      type: "race_start",
      text: text
    })

    Process.send_after(self(), :race_timeout, @timeout_ms)
    {:noreply, new_state}
  end

  def handle_info({:countdown, seconds}, state) do
    broadcast(state, %{type: "countdown", seconds: seconds})
    Process.send_after(self(), {:countdown, seconds - 1}, 1000)
    {:noreply, state}
  end

  def handle_info(:race_timeout, state) do
    if state.status == :racing do
      end_race(state)
    else
      {:noreply, state}
    end
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # Private helpers

  defp end_race(state) do
    new_state = %{state | status: :finished}

    results =
      state.players
      |> Enum.map(fn {_name, p} -> p end)
      |> Enum.sort_by(fn p ->
        cond do
          p.finished -> {0, p.position}
          true -> {1, 0}
        end
      end)
      |> Enum.with_index(1)
      |> Enum.map(fn {p, idx} ->
        pos = if p.finished, do: p.position, else: idx

        %{
          name: p.name,
          wpm: p.wpm,
          time_ms: p.time_ms,
          position: pos,
          finished: p.finished
        }
      end)

    broadcast(new_state, %{type: "race_over", results: results})
    Process.send_after(self(), :shutdown, 60_000)
    {:noreply, new_state}
  end

  defp broadcast(state, message) do
    encoded = Jason.encode!(message)

    Enum.each(state.sockets, fn {_name, pid} ->
      send(pid, {:broadcast, encoded})
    end)
  end

  defp format_player_list(players) do
    Enum.map(players, fn {name, _p} ->
      %{name: name, ready: true}
    end)
  end

  defp format_progress(players) do
    Enum.map(players, fn {_name, p} ->
      %{name: p.name, percent: p.percent, wpm: p.wpm}
    end)
  end
end
