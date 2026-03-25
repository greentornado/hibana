defmodule SystemMonitor.Collector do
  use GenServer

  @collect_interval 2_000
  @max_snapshots 60

  ## Client API

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def subscribe(pid) do
    GenServer.call(__MODULE__, {:subscribe, pid})
  end

  def unsubscribe(pid) do
    GenServer.cast(__MODULE__, {:unsubscribe, pid})
  end

  def latest_snapshot do
    GenServer.call(__MODULE__, :latest_snapshot)
  end

  def all_snapshots do
    GenServer.call(__MODULE__, :all_snapshots)
  end

  def top_processes(limit \\ 50) do
    Process.list()
    |> Enum.map(fn pid ->
      case Process.info(pid, [:registered_name, :memory, :message_queue_len, :current_function]) do
        nil ->
          nil

        info ->
          %{
            pid: inspect(pid),
            name: case info[:registered_name] do
              [] -> nil
              name -> name
            end,
            memory: info[:memory],
            message_queue: info[:message_queue_len],
            current_function: inspect(info[:current_function])
          }
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory, :desc)
    |> Enum.take(limit)
  end

  def ets_tables do
    :ets.all()
    |> Enum.map(fn table ->
      try do
        info = :ets.info(table)

        %{
          name: inspect(info[:name] || table),
          id: inspect(table),
          size: info[:size],
          memory: info[:memory] * :erlang.system_info(:wordsize),
          type: info[:type],
          protection: info[:protection]
        }
      rescue
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.memory, :desc)
  end

  def memory_detail do
    memory = :erlang.memory()

    %{
      total: memory[:total],
      processes: memory[:processes],
      processes_used: memory[:processes_used],
      system: memory[:system],
      atom: memory[:atom],
      atom_used: memory[:atom_used],
      binary: memory[:binary],
      code: memory[:code],
      ets: memory[:ets]
    }
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    :timer.send_interval(@collect_interval, :collect)
    snapshot = collect_snapshot()

    {:ok,
     %{
       snapshots: [snapshot],
       subscribers: MapSet.new()
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    Process.monitor(pid)
    {:reply, :ok, %{state | subscribers: MapSet.put(state.subscribers, pid)}}
  end

  def handle_call(:latest_snapshot, _from, state) do
    snapshot = List.first(state.snapshots)
    {:reply, snapshot, state}
  end

  def handle_call(:all_snapshots, _from, state) do
    {:reply, Enum.reverse(state.snapshots), state}
  end

  @impl true
  def handle_cast({:unsubscribe, pid}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(:collect, state) do
    snapshot = collect_snapshot()

    snapshots =
      [snapshot | state.snapshots]
      |> Enum.take(@max_snapshots)

    # Notify all subscribers
    Enum.each(state.subscribers, fn pid ->
      send(pid, {:metrics, snapshot})
    end)

    {:noreply, %{state | snapshots: snapshots}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  ## Private

  defp collect_snapshot do
    {wall_time_ms, _} = :erlang.statistics(:wall_clock)
    {{:input, input}, {:output, output}} = :erlang.statistics(:io)

    %{
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      memory: %{
        total: :erlang.memory(:total),
        processes: :erlang.memory(:processes),
        ets: :erlang.memory(:ets),
        atom: :erlang.memory(:atom),
        binary: :erlang.memory(:binary),
        code: :erlang.memory(:code)
      },
      processes: %{
        count: :erlang.system_info(:process_count),
        limit: :erlang.system_info(:process_limit)
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        total: :erlang.system_info(:schedulers)
      },
      uptime_seconds: div(wall_time_ms, 1000),
      run_queue: :erlang.statistics(:run_queue),
      io: %{
        input: input,
        output: output
      },
      ets_tables: :ets.all() |> length(),
      ports: :erlang.system_info(:port_count),
      atoms: %{
        count: :erlang.system_info(:atom_count),
        limit: :erlang.system_info(:atom_limit)
      }
    }
  end
end
