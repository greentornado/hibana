defmodule Hibana.Queue do
  @moduledoc """
  Persistent background job queue with GenServer and Erlang processes.

  ## Usage

      # Define a job
      defmodule SendEmailJob do
        use Hibana.Queue.Job

        def perform(data) do
          IO.puts("Sending email to: \#{data[:to]}")
        end
      end

      # Enqueue with delay (in milliseconds)
      SendEmailJob.enqueue(%{to: "user@example.com"}, delay: 5000)

      # Enqueue with retry
      SendEmailJob.enqueue(%{to: "user@example.com"}, retry: 3)

  """

  defmodule Job do
    @moduledoc false
    defmacro __using__(_opts \\ []) do
      quote do
        @behaviour unquote(__MODULE__)

        def perform(_args) do
          raise "perform/1 must be implemented"
        end

        def enqueue(args, opts \\ []) do
          Hibana.Queue.enqueue(__MODULE__, args, opts)
        end

        def enqueue_at(args, at, opts \\ []) do
          Hibana.Queue.enqueue_at(__MODULE__, args, at, opts)
        end

        defoverridable perform: 1
      end
    end

    @callback perform(args :: any()) :: any()
  end

  use GenServer
  require Logger

  @ets_table :job_queue

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_opts) do
    # Clean up existing table if present (from crash restart)
    try do
      :ets.delete(@ets_table)
    catch
      _, _ -> :ok
    end

    # Use :protected instead of :public for safety
    # Writes will be routed through GenServer to prevent race conditions
    :ets.new(@ets_table, [
      :ordered_set,
      :named_table,
      :protected,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.send_after(self(), :process_queue, 1000)
    {:ok, %{}}
  end

  @doc """
  Cleanup ETS table on termination to prevent table leak on restart.
  """
  def terminate(_reason, _state) do
    try do
      :ets.delete(@ets_table)
    catch
      _, _ -> :ok
    end

    :ok
  end

  def handle_info(:process_queue, state) do
    process_jobs()
    Process.send_after(self(), :process_queue, 1000)
    {:noreply, state}
  end

  defp process_jobs do
    now = System.system_time(:millisecond)

    # First, promote scheduled jobs that are ready
    scheduled =
      :ets.select(@ets_table, [
        {{{:_, :_, :_}, :_, :_, :_, {:scheduled, :"$1"}}, [{:"=<", :"$1", now}], [:"$_"]}
      ])

    Enum.each(scheduled, fn {key, inserted, retry, max, {:scheduled, at}} ->
      :ets.insert(@ets_table, {key, inserted, retry, max, {:available, at}})
    end)

    # Then process all available jobs that are ready
    available =
      :ets.select(@ets_table, [
        {{{:_, :_, :_}, :_, :_, :_, {:available, :"$1"}}, [{:"=<", :"$1", now}], [:"$_"]}
      ])

    Enum.each(available, fn job -> execute_job(job) end)
  end

  defp execute_job({{mod, args, id}, _inserted_at, retry, max_retries, _status}) do
    # Spawn supervised task via GenServer call to ensure proper cleanup
    GenServer.cast(__MODULE__, {:execute_job, mod, args, id, retry, max_retries})
  end

  def handle_cast({:execute_job, mod, args, id, retry, max_retries}, state) do
    Task.start(fn ->
      result =
        try do
          apply(mod, :perform, [args])
          :ok
        rescue
          e -> {:error, e}
        catch
          kind, reason -> {:error, {kind, reason}}
        end

      # Send result back to GenServer for stateful operations
      GenServer.call(__MODULE__, {:job_complete, {mod, args, id}, result, retry, max_retries})
    end)

    {:noreply, state}
  end

  def handle_call({:job_complete, job_key, result, retry, max_retries}, _from, state) do
    ets_table = @ets_table

    case result do
      :ok ->
        :ets.delete(ets_table, job_key)
        Logger.info("Job completed: #{inspect(elem(job_key, 0))}")
        {:reply, :ok, state}

      {:error, _} when retry < max_retries ->
        new_retry = retry + 1
        new_ready_at = System.system_time(:millisecond) + 1000 * round(:math.pow(2, new_retry))

        :ets.update_element(ets_table, job_key, [
          {5, {:available, new_ready_at}},
          {3, new_retry}
        ])

        Logger.warning("Job failed, retry #{new_retry}: #{inspect(elem(job_key, 0))}")
        {:reply, :ok, state}

      {:error, _} ->
        :ets.delete(ets_table, job_key)
        Logger.warning("Job failed permanently: #{inspect(elem(job_key, 0))}")
        {:reply, :ok, state}
    end
  end

  @doc """
  Handle enqueue requests via GenServer to ensure thread-safe writes.
  """
  def handle_call({:enqueue, module, args, delay, max_retries}, _from, state) do
    id = generate_id()
    ready_at = System.system_time(:millisecond) + delay

    :ets.insert(@ets_table, {
      {module, args, id},
      System.system_time(:millisecond),
      0,
      max_retries,
      {:available, ready_at}
    })

    Logger.debug("Job enqueued: #{module} (id: #{id})")
    {:reply, {:ok, id}, state}
  end

  @doc """
  Handle enqueue_at requests via GenServer to ensure thread-safe writes.
  """
  def handle_call({:enqueue_at, module, args, at, max_retries}, _from, state) do
    id = generate_id()

    :ets.insert(@ets_table, {
      {module, args, id},
      System.system_time(:millisecond),
      0,
      max_retries,
      {:scheduled, at}
    })

    {:reply, {:ok, id}, state}
  end

  @doc """
  Enqueues a job to be processed by the queue worker.

  Jobs are stored in ETS and processed asynchronously. Failed jobs are
  retried with exponential backoff.

  ## Parameters

    - `module` - The job module (must implement `perform/1`)
    - `args` - Arguments passed to `module.perform/1`
    - `opts` - Options:
      - `:delay` - Delay before processing in milliseconds (default: `0`)
      - `:retry` - Maximum number of retries on failure (default: `3`)

  ## Returns

    - `{:ok, id}` - The unique job ID

  ## Examples

      ```elixir
      {:ok, id} = Hibana.Queue.enqueue(SendEmailJob, %{to: "user@example.com"})
      {:ok, id} = Hibana.Queue.enqueue(SendEmailJob, %{to: "user@example.com"}, delay: 5000, retry: 5)
      ```
  """
  def enqueue(module, args, opts \\ []) do
    delay = Keyword.get(opts, :delay, 0)
    max_retries = Keyword.get(opts, :retry, 3)

    # Route through GenServer to ensure thread-safe writes
    GenServer.call(__MODULE__, {:enqueue, module, args, delay, max_retries})
  end

  @doc """
  Enqueues a job to be processed at a specific Unix timestamp (in milliseconds).

  The job remains in `:scheduled` status until the given time, then transitions
  to `:available` for processing.

  ## Parameters

    - `module` - The job module (must implement `perform/1`)
    - `args` - Arguments passed to `module.perform/1`
    - `at` - Unix timestamp in milliseconds when the job should run
    - `opts` - Options:
      - `:retry` - Maximum number of retries on failure (default: `3`)

  ## Returns

    - `{:ok, id}` - The unique job ID

  ## Examples

      ```elixir
      future = System.system_time(:millisecond) + 60_000
      {:ok, id} = Hibana.Queue.enqueue_at(MyJob, %{data: "value"}, future)
      ```
  """
  def enqueue_at(module, args, at, opts \\ []) when is_integer(at) do
    max_retries = Keyword.get(opts, :retry, 3)

    # Route through GenServer to ensure thread-safe writes
    GenServer.call(__MODULE__, {:enqueue_at, module, args, at, max_retries})
  end

  @doc """
  Returns queue statistics.

  ## Returns

  A map with `:total`, `:available`, and `:scheduled` job counts.

  ## Examples

      ```elixir
      Hibana.Queue.stats()
      # => %{total: 42, available: 30, scheduled: 12}
      ```
  """
  def stats do
    total = :ets.info(@ets_table, :size)

    available =
      :ets.select_count(@ets_table, [
        {{{:_, :_, :_}, :_, :_, :_, {:available, :_}}, [], [true]}
      ])

    scheduled =
      :ets.select_count(@ets_table, [
        {{{:_, :_, :_}, :_, :_, :_, {:scheduled, :_}}, [], [true]}
      ])

    %{total: total, available: available, scheduled: scheduled}
  end

  @doc """
  Clears all jobs from the queue.

  ## Returns

  `:ok`
  """
  def clear do
    :ets.delete_all_objects(@ets_table)
    :ok
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode64()
  end

  @doc "Return a child specification for use in a supervision tree."
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5_000
    }
  end
end
