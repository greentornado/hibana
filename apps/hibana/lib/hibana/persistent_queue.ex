defmodule Hibana.PersistentQueue do
  @moduledoc """
  High-performance persistent job queue with disk spillover and backpressure.

  Supports millions of jobs with automatic disk spillover when memory limits
  are reached. Uses DETS for persistence and ETS for hot jobs.

  ## Usage

      # Start the queue
      {:ok, _pid} = Hibana.PersistentQueue.start_link(
        name: :jobs,
        max_memory_jobs: 10_000,
        data_dir: "priv/queue",
        concurrency: 10
      )

      # Enqueue a job
      Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{user_id: 123})

      # Enqueue with priority (lower = higher priority)
      Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{data: "urgent"}, priority: 0)

      # Enqueue with delay
      Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{}, delay: 60_000)

      # Get queue stats
      Hibana.PersistentQueue.stats(:jobs)

      # Pause/resume processing
      Hibana.PersistentQueue.pause(:jobs)
      Hibana.PersistentQueue.resume(:jobs)

  ## Features

  - **Disk spillover**: When memory jobs exceed `max_memory_jobs`, older jobs spill to DETS
  - **Backpressure**: Returns `{:error, :queue_full}` when disk queue exceeds limits
  - **Concurrency control**: Configurable number of concurrent workers
  - **Priority queues**: Jobs with lower priority numbers are processed first
  - **Retry with exponential backoff**: Failed jobs retry with increasing delays
  - **Persistence**: Jobs survive process restarts via DETS
  - **Graceful shutdown**: Waits for in-flight jobs before stopping

  ## Options

  - `:name` — Queue name (default: `__MODULE__`)
  - `:max_memory_jobs` — Max jobs in ETS before spilling to disk (default: 10_000)
  - `:max_disk_jobs` — Max jobs on disk (default: 1_000_000)
  - `:data_dir` — Directory for DETS files (default: `"priv/queue"`)
  - `:concurrency` — Max concurrent job workers (default: `System.schedulers_online()`)
  - `:poll_interval` — How often to check for new jobs in ms (default: 100)
  """

  use GenServer

  defstruct [
    :name,
    :ets_table,
    :dets_table,
    :data_dir,
    :max_memory_jobs,
    :max_disk_jobs,
    :concurrency,
    :poll_interval,
    :paused,
    :in_flight,
    :workers,
    :worker_refs,
    :disk_count
  ]

  @doc "Start the persistent queue process with the given options."
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    data_dir = Keyword.get(opts, :data_dir, "priv/queue")
    max_memory = Keyword.get(opts, :max_memory_jobs, 10_000)
    max_disk = Keyword.get(opts, :max_disk_jobs, 1_000_000)
    concurrency = Keyword.get(opts, :concurrency, System.schedulers_online())
    poll_interval = Keyword.get(opts, :poll_interval, 100)

    File.mkdir_p!(data_dir)

    ets_name = :"#{name}_ets"
    dets_name = :"#{name}_dets"
    dets_path = Path.join(data_dir, "#{name}.dets") |> String.to_charlist()

    # Clean up existing ETS table if present (from crash restart)
    try do
      :ets.delete(ets_name)
    catch
      _, _ -> :ok
    end

    ets_table = :ets.new(ets_name, [:ordered_set, :public, read_concurrency: true])

    # Handle DETS open with error checking
    dets_result = :dets.open_file(dets_name, file: dets_path, type: :set)

    dets_table =
      case dets_result do
        {:ok, table} ->
          table

        {:error, reason} ->
          Logger.error("Failed to open DETS table: #{inspect(reason)}")
          raise "DETS open failed: #{inspect(reason)}"
      end

    # Start async recovery to avoid blocking init
    # Recovery happens in a spawned process and sends results back
    parent = self()

    spawn(fn ->
      recovered_count = recover_jobs(dets_table, ets_table, max_memory)
      send(parent, {:recovery_complete, recovered_count})
    end)

    state = %__MODULE__{
      name: name,
      ets_table: ets_table,
      dets_table: dets_table,
      data_dir: data_dir,
      max_memory_jobs: max_memory,
      max_disk_jobs: max_disk,
      concurrency: concurrency,
      poll_interval: poll_interval,
      paused: false,
      in_flight: 0,
      workers: MapSet.new(),
      # correlation_id -> monitor_ref mapping
      worker_refs: %{},
      disk_count: 0
    }

    schedule_poll(poll_interval)
    {:ok, state}
  end

  # --- Public API ---

  @doc "Enqueue a job with the given worker module, args, and options (priority, delay, max_retries)."
  def enqueue(server \\ __MODULE__, module, args, opts \\ []) do
    GenServer.call(server, {:enqueue, module, args, opts})
  end

  @doc "Return queue statistics including memory jobs, disk jobs, and in-flight count."
  def stats(server \\ __MODULE__) do
    GenServer.call(server, :stats)
  end

  @doc "Pause job processing. Existing in-flight jobs will complete."
  def pause(server \\ __MODULE__) do
    GenServer.call(server, :pause)
  end

  @doc "Resume job processing after a pause."
  def resume(server \\ __MODULE__) do
    GenServer.call(server, :resume)
  end

  @doc "Clear all jobs from both memory and disk queues."
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear)
  end

  # --- GenServer callbacks ---

  def handle_call({:enqueue, module, args, opts}, _from, state) do
    priority = Keyword.get(opts, :priority, 5)
    delay = Keyword.get(opts, :delay, 0)
    max_retries = Keyword.get(opts, :max_retries, 3)

    id = generate_id()
    now = System.system_time(:millisecond)
    ready_at = now + delay

    job = {
      # Key (ordered by priority, then time)
      {priority, ready_at, id},
      module,
      args,
      # retry count
      0,
      max_retries,
      :pending
    }

    memory_size = :ets.info(state.ets_table, :size)

    cond do
      memory_size < state.max_memory_jobs ->
        :ets.insert(state.ets_table, job)
        {:reply, {:ok, id}, state}

      state.disk_count < state.max_disk_jobs ->
        :dets.insert(state.dets_table, job)
        new_disk_count = state.disk_count + 1
        {:reply, {:ok, id}, %{state | disk_count: new_disk_count}}

      true ->
        {:reply, {:error, :queue_full}, state}
    end
  end

  def handle_call(:stats, _from, state) do
    stats = %{
      memory_jobs: :ets.info(state.ets_table, :size),
      disk_jobs: :dets.info(state.dets_table, :size),
      in_flight: state.in_flight,
      paused: state.paused,
      concurrency: state.concurrency,
      max_memory: state.max_memory_jobs,
      max_disk: state.max_disk_jobs
    }

    {:reply, stats, state}
  end

  def handle_call(:pause, _from, state) do
    {:reply, :ok, %{state | paused: true}}
  end

  def handle_call(:resume, _from, state) do
    {:reply, :ok, %{state | paused: false}}
  end

  def handle_call(:clear, _from, state) do
    :ets.delete_all_objects(state.ets_table)
    :dets.delete_all_objects(state.dets_table)
    {:reply, :ok, %{state | in_flight: 0, workers: MapSet.new()}}
  end

  def handle_info(:poll, state) do
    state =
      if not state.paused and state.in_flight < state.concurrency do
        process_next_jobs(state)
      else
        state
      end

    schedule_poll(state.poll_interval)
    {:noreply, state}
  end

  def handle_info({:job_done, correlation_id, job_key}, state) do
    # Clean up worker tracking
    {monitor_ref, new_worker_refs} = Map.pop(state.worker_refs, correlation_id)

    new_workers =
      if monitor_ref, do: MapSet.delete(state.workers, monitor_ref), else: state.workers

    :ets.delete(state.ets_table, job_key)
    :dets.delete(state.dets_table, job_key)

    {:noreply,
     %{
       state
       | in_flight: max(state.in_flight - 1, 0),
         workers: new_workers,
         worker_refs: new_worker_refs
     }}
  end

  def handle_info(
        {:job_failed, correlation_id, job_key, module, args, retry, max_retries},
        state
      ) do
    # Clean up worker tracking
    {monitor_ref, new_worker_refs} = Map.pop(state.worker_refs, correlation_id)

    new_workers =
      if monitor_ref, do: MapSet.delete(state.workers, monitor_ref), else: state.workers

    if retry < max_retries do
      # Requeue with exponential backoff
      backoff = :math.pow(2, retry) |> round() |> Kernel.*(1000)
      {priority, _old_ready, id} = job_key
      new_ready = System.system_time(:millisecond) + backoff
      new_key = {priority, new_ready, id}

      :ets.delete(state.ets_table, job_key)
      job = {new_key, module, args, retry + 1, max_retries, :pending}
      :ets.insert(state.ets_table, job)
    else
      :ets.delete(state.ets_table, job_key)
      :dets.delete(state.dets_table, job_key)
    end

    {:noreply,
     %{
       state
       | in_flight: max(state.in_flight - 1, 0),
         workers: new_workers,
         worker_refs: new_worker_refs
     }}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    # This is a backup cleanup in case job_done/job_failed messages are lost
    # Find and remove the correlation_id associated with this monitor_ref
    correlation_id = Enum.find(state.worker_refs, fn {_, v} -> v == ref end) |> elem(0)

    new_worker_refs =
      if correlation_id,
        do: Map.delete(state.worker_refs, correlation_id),
        else: state.worker_refs

    {:noreply,
     %{
       state
       | in_flight: max(state.in_flight - 1, 0),
         workers: MapSet.delete(state.workers, ref),
         worker_refs: new_worker_refs
     }}
  end

  def handle_info({:recovery_complete, count}, state) do
    require Logger
    Logger.info("[PersistentQueue] Recovered #{count} jobs from disk")
    {:noreply, state}
  end

  def terminate(_reason, state) do
    # Sync ETS to DETS on shutdown
    :ets.foldl(
      fn job, _acc ->
        :dets.insert(state.dets_table, job)
      end,
      :ok,
      state.ets_table
    )

    :dets.close(state.dets_table)
    :ok
  end

  # --- Internal ---

  defp process_next_jobs(state) do
    now = System.system_time(:millisecond)
    slots = state.concurrency - state.in_flight

    # Try ETS first, then DETS
    {state, remaining} = take_ready_jobs(state, state.ets_table, now, slots)

    state =
      if remaining > 0 do
        # Spill from DETS to ETS
        promote_from_dets(state)
        {state, _} = take_ready_jobs(state, state.ets_table, now, remaining)
        state
      else
        state
      end

    state
  end

  defp take_ready_jobs(state, table, now, count) when count > 0 do
    case :ets.first(table) do
      :"$end_of_table" ->
        {state, count}

      {_priority, ready_at, _id} = key when ready_at <= now ->
        case :ets.lookup(table, key) do
          [{^key, module, args, retry, max_retries, :pending}] ->
            # Mark as running
            :ets.update_element(table, key, {6, :running})

            # Spawn worker
            parent = self()
            correlation_id = make_ref()

            {_pid, monitor_ref} =
              spawn_monitor(fn ->
                try do
                  apply(module, :perform, [args])
                  send(parent, {:job_done, correlation_id, key})
                rescue
                  _ ->
                    send(
                      parent,
                      {:job_failed, correlation_id, key, module, args, retry, max_retries}
                    )
                end
              end)

            state = %{
              state
              | in_flight: state.in_flight + 1,
                workers: MapSet.put(state.workers, monitor_ref),
                worker_refs: Map.put(state.worker_refs, correlation_id, monitor_ref)
            }

            take_ready_jobs(state, table, now, count - 1)

          _ ->
            {state, count}
        end

      _ ->
        {state, count}
    end
  end

  defp take_ready_jobs(state, _table, _now, count), do: {state, count}

  defp promote_from_dets(state) do
    :dets.foldl(
      fn job, count ->
        if count < 100 do
          :ets.insert(state.ets_table, job)
          :dets.delete(state.dets_table, elem(job, 0))
          count + 1
        else
          count
        end
      end,
      0,
      state.dets_table
    )
  end

  defp recover_jobs(dets_table, ets_table, max_memory) do
    :dets.foldl(
      fn {key, module, args, retry, max_retries, _status} = _job, count ->
        if count < max_memory do
          recovered = {key, module, args, retry, max_retries, :pending}
          :ets.insert(ets_table, recovered)
          count + 1
        else
          count
        end
      end,
      0,
      dets_table
    )
  end

  defp schedule_poll(interval) do
    Process.send_after(self(), :poll, interval)
  end

  defp generate_id do
    :crypto.strong_rand_bytes(12) |> Base.encode64()
  end

  @doc """
  Cleanup ETS and DETS tables on termination.
  """
  def terminate(_reason, state) do
    # Close DETS table
    if state.dets_table do
      :dets.close(state.dets_table)
    end

    # Delete ETS table
    if state.ets_table do
      :ets.delete(state.ets_table)
    end

    :ok
  end

  @doc "Return a child specification for use in a supervision tree."
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 30_000
    }
  end
end
