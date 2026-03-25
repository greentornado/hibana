defmodule LivePoll.PollNotifier do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    {:ok, %{subscribers: %{}}}
  end

  @doc "Subscribe the calling process to updates for a poll."
  def subscribe(poll_id) do
    GenServer.call(__MODULE__, {:subscribe, poll_id, self()})
  end

  @doc "Unsubscribe the calling process from a poll."
  def unsubscribe(poll_id) do
    GenServer.cast(__MODULE__, {:unsubscribe, poll_id, self()})
  end

  @doc "Broadcast an event to all subscribers of a poll."
  def broadcast(poll_id, event_type, data) do
    GenServer.cast(__MODULE__, {:broadcast, poll_id, event_type, data})
  end

  # Callbacks

  def handle_call({:subscribe, poll_id, pid}, _from, state) do
    Process.monitor(pid)
    subs = Map.get(state.subscribers, poll_id, MapSet.new())
    new_subs = MapSet.put(subs, pid)
    new_state = %{state | subscribers: Map.put(state.subscribers, poll_id, new_subs)}
    {:reply, :ok, new_state}
  end

  def handle_cast({:unsubscribe, poll_id, pid}, state) do
    subs = Map.get(state.subscribers, poll_id, MapSet.new())
    new_subs = MapSet.delete(subs, pid)

    new_subscribers =
      if MapSet.size(new_subs) == 0 do
        Map.delete(state.subscribers, poll_id)
      else
        Map.put(state.subscribers, poll_id, new_subs)
      end

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  def handle_cast({:broadcast, poll_id, event_type, data}, state) do
    subs = Map.get(state.subscribers, poll_id, MapSet.new())

    Enum.each(subs, fn pid ->
      send(pid, {:sse_event, event_type, data})
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    new_subscribers =
      state.subscribers
      |> Enum.map(fn {poll_id, subs} -> {poll_id, MapSet.delete(subs, pid)} end)
      |> Enum.reject(fn {_poll_id, subs} -> MapSet.size(subs) == 0 end)
      |> Map.new()

    {:noreply, %{state | subscribers: new_subscribers}}
  end
end
