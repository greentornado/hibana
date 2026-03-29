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
      {:ok, _} = Hibana.Queue.start_link(name: :test_job_queue)

      result = TestJob.enqueue(%{test_pid: self(), value: 42})
      assert result == :ok

      GenServer.stop(:test_job_queue)
    end

    test "job is executed asynchronously" do
      {:ok, _} = Hibana.Queue.start_link(name: :test_job_queue_2)

      TestJob.enqueue(%{test_pid: self(), value: 100})

      assert_receive {:job_done, 100}, 2000

      GenServer.stop(:test_job_queue_2)
    end

    test "job can specify delay" do
      {:ok, _} = Hibana.Queue.start_link(name: :test_job_queue_3)

      start_time = System.monotonic_time(:millisecond)

      TestJob.enqueue(%{test_pid: self(), value: 1}, delay: 500)

      assert_receive {:job_done, 1}, 2000

      end_time = System.monotonic_time(:millisecond)
      assert end_time - start_time >= 400

      GenServer.stop(:test_job_queue_3)
    end

    test "job respects retry configuration" do
      # Verify that the job module has retry config
      assert RetryJob.__info__(:attributes)[:retry] == 5
    end
  end
end
