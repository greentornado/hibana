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
    :ets.new(@ets_table, [
      :ordered_set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])

    Process.send_after(self(), :process_queue, 1000)
    {:ok, %{}}
  end

  def handle_info(:process_queue, state) do
    process_jobs()
    Process.send_after(self(), :process_queue, 1000)
    {:noreply, state}
  end

  defp process_jobs do
    now = System.system_time(:millisecond)

    # First, promote scheduled jobs that are ready
    scheduled = :ets.match_object(@ets_table, {{:_, :_, :_}, :_, :_, :_, {:scheduled, :_}})

    Enum.each(scheduled, fn {key, inserted, retry, max, {:scheduled, at}} ->
      if now >= at do
        :ets.insert(@ets_table, {key, inserted, retry, max, {:available, at}})
      end
    end)

    # Then process all available jobs
    available = :ets.match_object(@ets_table, {{:_, :_, :_}, :_, :_, :_, {:available, :_}})

    Enum.each(available, fn {_key, _inserted, _retry, _max, {:available, ready_at}} = job ->
      if now >= ready_at do
        execute_job(job)
      end
    end)
  end

  defp execute_job({{mod, args, id}, _inserted_at, retry, max_retries, _status}) do
    ets_table = @ets_table

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

      case result do
        :ok ->
          :ets.delete(ets_table, {mod, args, id})
          Logger.info("Job completed: \#{inspect(mod)}")

        {:error, _} when retry < max_retries ->
          new_retry = retry + 1
          new_ready_at = System.system_time(:millisecond) + 1000 * round(:math.pow(2, new_retry))

          :ets.update_element(ets_table, {mod, args, id}, [
            {5, {:available, new_ready_at}},
            {3, new_retry}
          ])

          Logger.warning("Job failed, retry \#{new_retry}: \#{inspect(mod)}")

        {:error, _} ->
          :ets.delete(ets_table, {mod, args, id})
          Logger.warning("Job failed permanently: \#{inspect(mod)}")
      end
    end)
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
    id = generate_id()
    delay = Keyword.get(opts, :delay, 0)
    max_retries = Keyword.get(opts, :retry, 3)

    ready_at = System.system_time(:millisecond) + delay

    :ets.insert(@ets_table, {
      {module, args, id},
      System.system_time(:millisecond),
      0,
      max_retries,
      {:available, ready_at}
    })

    Logger.debug("Job enqueued: \#{module} (id: \#{id})")
    {:ok, id}
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
    id = generate_id()
    max_retries = Keyword.get(opts, :retry, 3)

    :ets.insert(@ets_table, {
      {module, args, id},
      System.system_time(:millisecond),
      0,
      max_retries,
      {:scheduled, at}
    })

    {:ok, id}
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
      length(:ets.match_object(@ets_table, {{:_, :_, :_}, :_, :_, :_, {:available, :_}}))

    scheduled =
      length(:ets.match_object(@ets_table, {{:_, :_, :_}, :_, :_, :_, {:scheduled, :_}}))

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
end
