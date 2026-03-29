defmodule Hibana.JobTest do
  use ExUnit.Case, async: false

  alias Hibana.Job
  alias Hibana.Job.Worker

  describe "Job.Worker" do
    setup do
      {:ok, pid} = Worker.start_link(name: :test_job_worker)

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end
      end)

      {:ok, worker_pid: pid}
    end

    test "start_link with default name" do
      {:ok, pid} = Worker.start_link([])
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "start_link with custom name" do
      {:ok, pid} = Worker.start_link(name: :custom_worker)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "init starts Task.Supervisor" do
      {:ok, pid} = Worker.start_link([])
      # Verify Task.Supervisor was started
      assert Process.whereis(:job_task_supervisor) != nil
      GenServer.stop(pid)
    end

    test "enqueue/3 adds job to queue", %{worker_pid: _pid} do
      defmodule SimpleJob do
        def perform(_args), do: :ok
      end

      result = Worker.enqueue(SimpleJob, %{}, :test_job_worker)
      assert result == :ok
    end

    test "enqueue/2 uses default worker" do
      defmodule DefaultJobWorker do
        def perform(_args), do: :ok
      end

      # Should use default __MODULE__ worker
      result = Worker.enqueue(DefaultJobWorker, {})
      assert result == :ok
    end

    test "worker executes job asynchronously", %{worker_pid: _pid} do
      test_pid = self()

      defmodule AsyncJob do
        def perform(args) do
          send(args[:test_pid], {:job_executed, args[:value]})
        end
      end

      Worker.enqueue(AsyncJob, %{test_pid: test_pid, value: 42}, :test_job_worker)

      # Job should be executed
      assert_receive {:job_executed, 42}, 2000
    end

    test "worker handles job failures gracefully", %{worker_pid: _pid} do
      defmodule FailingJob do
        def perform(_args) do
          raise "Intentional failure"
        end
      end

      # Should not crash the worker
      result = Worker.enqueue(FailingJob, %{}, :test_job_worker)
      assert result == :ok

      # Give time for error to be logged
      Process.sleep(100)
    end

    test "worker handles job throws gracefully", %{worker_pid: _pid} do
      defmodule ThrowingJob do
        def perform(_args) do
          throw(:intentional_throw)
        end
      end

      # Should not crash the worker
      result = Worker.enqueue(ThrowingJob, %{}, :test_job_worker)
      assert result == :ok

      Process.sleep(100)
    end

    test "worker handles job exits gracefully", %{worker_pid: _pid} do
      defmodule ExitingJob do
        def perform(_args) do
          exit(:intentional_exit)
        end
      end

      # Should not crash the worker
      result = Worker.enqueue(ExitingJob, %{}, :test_job_worker)
      assert result == :ok

      Process.sleep(100)
    end
  end

  describe "Job __using__ macro" do
    test "creates perform/1 function" do
      defmodule BasicJob do
        use Job
      end

      assert function_exported?(BasicJob, :perform, 1)
    end

    test "creates enqueue/1 function" do
      defmodule BasicJobEnqueue do
        use Job
      end

      assert function_exported?(BasicJobEnqueue, :enqueue, 1)
    end

    test "perform/1 is overridable" do
      defmodule CustomPerformJob do
        use Job

        def perform(args) do
          {:processed, args}
        end
      end

      assert CustomPerformJob.perform(%{data: "test"}) == {:processed, %{data: "test"}}
    end

    test "enqueue/1 is overridable" do
      defmodule CustomEnqueueJob do
        use Job

        def enqueue(args) do
          {:enqueued, args}
        end
      end

      assert CustomEnqueueJob.enqueue(%{data: "test"}) == {:enqueued, %{data: "test"}}
    end

    test "default perform/1 raises error" do
      defmodule NoOpJob do
        use Job
      end

      assert_raise RuntimeError, "perform/1 not implemented", fn ->
        NoOpJob.perform(%{})
      end
    end

    test "generated enqueue/1 calls Worker.enqueue" do
      # Start worker for this test
      {:ok, _pid} = Worker.start_link(name: Job.Worker)

      defmodule TestJob do
        use Job

        def perform(args) do
          send(args[:pid], {:performed, args[:value]})
        end
      end

      test_pid = self()
      result = TestJob.enqueue(%{pid: test_pid, value: 100})
      assert result == :ok

      assert_receive {:performed, 100}, 2000
    end
  end

  describe "Job execution integration" do
    setup do
      {:ok, pid} = Worker.start_link([])

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end
      end)

      {:ok, worker_pid: pid}
    end

    test "full job lifecycle - enqueue to execution", %{worker_pid: _pid} do
      defmodule LifecycleJob do
        use Job

        def perform(args) do
          send(args[:test_pid], {:completed, args[:job_id]})
        end
      end

      test_pid = self()

      # Enqueue the job
      result = LifecycleJob.enqueue(%{test_pid: test_pid, job_id: "job-123"})
      assert result == :ok

      # Verify job completed
      assert_receive {:completed, "job-123"}, 2000
    end

    test "multiple jobs can be enqueued and executed", %{worker_pid: _pid} do
      defmodule MultiJob do
        use Job

        def perform(args) do
          send(args[:test_pid], {:done, args[:index]})
        end
      end

      test_pid = self()

      # Enqueue multiple jobs
      for i <- 1..10 do
        MultiJob.enqueue(%{test_pid: test_pid, index: i})
      end

      # All jobs should complete
      for i <- 1..10 do
        assert_receive {:done, ^i}, 5000
      end
    end

    test "jobs with different types of args", %{worker_pid: _pid} do
      defmodule ArgsJob do
        use Job

        def perform(args) do
          send(args[:test_pid], {:received, args[:data]})
        end
      end

      test_pid = self()

      # Test with different arg types
      ArgsJob.enqueue(%{test_pid: test_pid, data: "string"})
      ArgsJob.enqueue(%{test_pid: test_pid, data: 123})
      ArgsJob.enqueue(%{test_pid: test_pid, data: [1, 2, 3]})
      ArgsJob.enqueue(%{test_pid: test_pid, data: %{key: "value"}})

      assert_receive {:received, "string"}, 2000
      assert_receive {:received, 123}, 2000
      assert_receive {:received, [1, 2, 3]}, 2000
      assert_receive {:received, %{key: "value"}}, 2000
    end
  end

  describe "Job error scenarios" do
    setup do
      {:ok, pid} = Worker.start_link([])

      on_exit(fn ->
        try do
          GenServer.stop(pid)
        catch
          _, _ -> :ok
        end
      end)

      {:ok, worker_pid: pid}
    end

    test "rescues exceptions in perform", %{worker_pid: _pid} do
      defmodule ExceptionJob do
        use Job

        def perform(_args) do
          raise ArgumentError, "test error"
        end
      end

      # Should not crash
      result = ExceptionJob.enqueue(%{})
      assert result == :ok
      Process.sleep(100)
    end

    test "catches throws in perform", %{worker_pid: _pid} do
      defmodule ThrowJob do
        use Job

        def perform(_args) do
          throw(:test_throw)
        end
      end

      # Should not crash
      result = ThrowJob.enqueue(%{})
      assert result == :ok
      Process.sleep(100)
    end

    test "handles exits in perform", %{worker_pid: _pid} do
      defmodule ExitJob do
        use Job

        def perform(_args) do
          exit(:test_exit)
        end
      end

      # Should not crash
      result = ExitJob.enqueue(%{})
      assert result == :ok
      Process.sleep(100)
    end

    test "worker continues after job failure", %{worker_pid: pid} do
      defmodule CrashThenWorkJob do
        use Job

        def perform(args) do
          if args[:should_fail] do
            raise "fail"
          end

          send(args[:test_pid], {:success, args[:id]})
        end
      end

      test_pid = self()

      # Enqueue failing job
      CrashThenWorkJob.enqueue(%{test_pid: test_pid, id: 1, should_fail: true})

      # Enqueue succeeding job
      CrashThenWorkJob.enqueue(%{test_pid: test_pid, id: 2, should_fail: false})

      # Worker should still process second job
      assert_receive {:success, 2}, 3000

      # Verify worker is still alive
      assert Process.alive?(pid)
    end
  end

  describe "Worker state management" do
    test "worker maintains state across calls" do
      {:ok, pid} = Worker.start_link([])

      defmodule StateJob do
        def perform(_args), do: :ok
      end

      # Multiple calls
      Worker.enqueue(StateJob, %{})
      Worker.enqueue(StateJob, %{})
      Worker.enqueue(StateJob, %{})

      # Worker should still be alive with empty state
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end
  end
end
