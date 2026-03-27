defmodule Hibana.EventStore do
  @moduledoc """
  Event sourcing with GenServer, ETS storage, projections, and subscriptions.

  ## Usage

      {:ok, store} = Hibana.EventStore.start_link(name: :my_store)

      Hibana.EventStore.append(store, "user-1", [
        %{type: "user_created", data: %{name: "Alice"}},
        %{type: "user_updated", data: %{name: "Bob"}}
      ])

      Hibana.EventStore.read(store, "user-1")

      Hibana.EventStore.subscribe(store, "user_*")

      Hibana.EventStore.register_projection(store, :user_count, fn
        %{type: "user_created"}, state -> (state || 0) + 1
        _, state -> state || 0
      end)

      Hibana.EventStore.projection(store, :user_count)
  """

  use GenServer

  # --- Client API ---

  @doc """
  Start the event store.
  """
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Append events to an aggregate stream.
  Events are maps with at least a `:type` key.
  """
  def append(server, aggregate_id, events) when is_list(events) do
    GenServer.call(server, {:append, aggregate_id, events})
  end

  @doc """
  Read all events for an aggregate.
  """
  def read(server, aggregate_id) do
    GenServer.call(server, {:read, aggregate_id})
  end

  @doc """
  Subscribe to events matching a pattern.
  Pattern supports wildcards with `*`.
  The calling process will receive `{:event, event}` messages.
  """
  def subscribe(server, pattern) do
    GenServer.call(server, {:subscribe, pattern, self()})
  end

  @doc """
  Unsubscribe from events.
  """
  def unsubscribe(server) do
    GenServer.call(server, {:unsubscribe, self()})
  end

  @doc """
  Register a projection with a reducer function.
  The reducer receives `(event, current_state)` and returns new state.
  Automatically replays all existing events.
  """
  def register_projection(server, name, reducer_fn) when is_function(reducer_fn, 2) do
    GenServer.call(server, {:register_projection, name, reducer_fn})
  end

  @doc """
  Get the current state of a projection.
  """
  def projection(server, name) do
    GenServer.call(server, {:projection, name})
  end

  @doc """
  Get all events in the store, ordered by sequence number.
  """
  def all_events(server) do
    GenServer.call(server, :all_events)
  end

  # --- Server Callbacks ---

  @impl true
  def init(opts) do
    table_name = Keyword.get(opts, :table_name, :hibana_event_store)

    events_table =
      :ets.new(table_name, [:ordered_set, :protected])

    aggregates_table =
      :ets.new(:"#{table_name}_aggregates", [:set, :protected])

    state = %{
      events_table: events_table,
      aggregates_table: aggregates_table,
      sequence: 0,
      subscribers: [],
      projections: %{}
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:append, aggregate_id, events}, _from, state) do
    {stored_events, new_state} =
      Enum.map_reduce(events, state, fn event, acc ->
        seq = acc.sequence + 1

        stored_event =
          event
          |> Map.put(:sequence, seq)
          |> Map.put(:aggregate_id, aggregate_id)
          |> Map.put(:timestamp, DateTime.utc_now())

        :ets.insert(acc.events_table, {seq, stored_event})

        # Update aggregate index
        existing =
          case :ets.lookup(acc.aggregates_table, aggregate_id) do
            [{_, seqs}] -> seqs
            [] -> []
          end

        :ets.insert(acc.aggregates_table, {aggregate_id, [seq | existing]})

        {stored_event, %{acc | sequence: seq}}
      end)

    # Update projections
    new_projections =
      Enum.reduce(stored_events, new_state.projections, fn event, projs ->
        Enum.reduce(projs, projs, fn {name, {reducer, current_state}}, acc ->
          new_proj_state = reducer.(event, current_state)
          Map.put(acc, name, {reducer, new_proj_state})
        end)
      end)

    new_state = %{new_state | projections: new_projections}

    # Notify subscribers
    Enum.each(stored_events, fn event ->
      notify_subscribers(new_state.subscribers, event)
    end)

    {:reply, {:ok, stored_events}, new_state}
  end

  def handle_call({:read, aggregate_id}, _from, state) do
    events =
      case :ets.lookup(state.aggregates_table, aggregate_id) do
        [{_, seqs}] ->
          seqs
          |> Enum.reverse()
          |> Enum.map(fn seq ->
            case :ets.lookup(state.events_table, seq) do
              [{_, event}] -> event
              [] -> nil
            end
          end)
          |> Enum.reject(&is_nil/1)

        [] ->
          []
      end

    {:reply, events, state}
  end

  def handle_call({:subscribe, pattern, pid}, _from, state) do
    ref = Process.monitor(pid)
    compiled_regex = compile_pattern(pattern)
    subscriber = %{pid: pid, pattern: pattern, compiled_regex: compiled_regex, ref: ref}
    {:reply, :ok, %{state | subscribers: [subscriber | state.subscribers]}}
  end

  def handle_call({:unsubscribe, pid}, _from, state) do
    {removed, remaining} = Enum.split_with(state.subscribers, fn s -> s.pid == pid end)
    Enum.each(removed, fn s -> Process.demonitor(s.ref, [:flush]) end)
    {:reply, :ok, %{state | subscribers: remaining}}
  end

  def handle_call({:register_projection, name, reducer}, _from, state) do
    # Replay all existing events to build initial projection state
    all = get_all_events(state.events_table)

    initial_state =
      Enum.reduce(all, nil, fn event, acc ->
        reducer.(event, acc)
      end)

    new_projections = Map.put(state.projections, name, {reducer, initial_state})
    {:reply, :ok, %{state | projections: new_projections}}
  end

  def handle_call({:projection, name}, _from, state) do
    case Map.get(state.projections, name) do
      {_reducer, current_state} -> {:reply, {:ok, current_state}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:all_events, _from, state) do
    events = get_all_events(state.events_table)
    {:reply, events, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    remaining = Enum.reject(state.subscribers, fn s -> s.pid == pid end)
    {:noreply, %{state | subscribers: remaining}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private ---

  defp get_all_events(table) do
    :ets.select(table, [{{:"$1", :"$2"}, [], [{{:"$1", :"$2"}}]}])
    |> Enum.sort_by(fn {seq, _} -> seq end)
    |> Enum.map(fn {_, event} -> event end)
  end

  defp notify_subscribers(subscribers, event) do
    event_type = Map.get(event, :type, "")

    Enum.each(subscribers, fn %{pid: pid, compiled_regex: regex} ->
      if Regex.match?(regex, to_string(event_type)) do
        send(pid, {:event, event})
      end
    end)
  end

  defp compile_pattern(pattern) do
    regex_pattern =
      pattern
      |> Regex.escape()
      |> String.replace("\\*", ".*")

    Regex.compile!("^#{regex_pattern}$")
  end
end
