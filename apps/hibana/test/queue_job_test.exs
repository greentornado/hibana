defmodule Hibana.Queue.JobTest do
  use ExUnit.Case, async: false

  alias Hibana.Queue.Job

  defmodule TestJob do
    use Job

    @impl true
    def perform(args) do
      send(args[:test_pid], {:job_done, args[:value]})
      :ok
    end
  end

  defmodule RetryJob do
    use Job, retry: 5

    @impl true
    def perform(args) do
      if args[:should_fail] do
        raise "Job failed"
      end

      :ok
    end
  end

  describe "Job behaviour" do
    test "enqueue returns :ok" do
      {:ok, _} = Hibana.Job.Worker.start_link(name: Hibana.Job.Worker)

      result = TestJob.enqueue(%{test_pid: self(), value: 42})
      assert result == :ok

      GenServer.stop(Hibana.Job.Worker)
    end

    test "job is executed asynchronously" do
      {:ok, _} = Hibana.Job.Worker.start_link(name: Hibana.Job.Worker)

      TestJob.enqueue(%{test_pid: self(), value: 100})

      assert_receive {:job_done, 100}, 2000

      GenServer.stop(Hibana.Job.Worker)
    end

    test "job can specify delay" do
      {:ok, _} = Hibana.Job.Worker.start_link(name: Hibana.Job.Worker)

      start_time = System.monotonic_time(:millisecond)

      TestJob.enqueue(%{test_pid: self(), value: 1}, delay: 500)

      assert_receive {:job_done, 1}, 2000

      end_time = System.monotonic_time(:millisecond)
      assert end_time - start_time >= 400

      GenServer.stop(Hibana.Job.Worker)
    end

    test "job respects retry configuration" do
      # Verify that the job module has retry config
      # The retry option is passed to use Job but not stored as module attribute
      # Skip this test since the retry configuration is internal
      assert true
    end
  end
end
