defmodule Hibana.Job do
  @moduledoc """
  Background job queue module using OTP.

  ## Usage

      defmodule MyJob do
        use Hibana.Job

        def perform(data) do
          IO.inspect(data, label: "Processing job")
        end
      end

      # Enqueue a job
      MyJob.enqueue(%{user_id: 123, action: "send_email"})

  """

  defmodule Worker do
    @moduledoc false
    use GenServer

    def start_link(opts) do
      name = Keyword.get(opts, :name, __MODULE__)
      GenServer.start_link(__MODULE__, opts, name: name)
    end

    def init(_opts) do
      # Start a Task.Supervisor for supervised job execution
      task_sup_opts = [name: :job_task_supervisor]
      {:ok, _pid} = Task.Supervisor.start_link(task_sup_opts)
      {:ok, %{}}
    end

    def handle_call({:enqueue, worker_module, args}, _from, state) do
      # Use supervised Task instead of bare spawn
      Task.Supervisor.start_child(:job_task_supervisor, fn ->
        try do
          apply(worker_module, :perform, [args])
        rescue
          _e ->
            require Logger
            Logger.error("Job failed")
        catch
          _kind, _reason ->
            require Logger
            Logger.error("Job crashed")
        end
      end)

      {:reply, :ok, state}
    end

    def enqueue(worker_module, args) do
      GenServer.call(__MODULE__, {:enqueue, worker_module, args})
    end
  end

  defmacro __using__(_opts \\ []) do
    quote do
      def enqueue(args) do
        Hibana.Job.Worker.enqueue(__MODULE__, args)
      end

      def perform(_args) do
        raise "perform/1 not implemented"
      end

      defoverridable perform: 1, enqueue: 1
    end
  end
end
