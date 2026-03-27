defmodule Hibana.JobTest do
  use ExUnit.Case, async: false

  describe "__using__/1" do
    test "creates perform/1 function" do
      defmodule BasicJob do
        use Hibana.Job
      end

      assert function_exported?(BasicJob, :perform, 1)
    end

    test "creates enqueue/1 function" do
      defmodule BasicJobEnqueue do
        use Hibana.Job
      end

      assert function_exported?(BasicJobEnqueue, :enqueue, 1)
    end
  end

  describe "perform/1" do
    test "default implementation raises error" do
      defmodule NoOpJob do
        use Hibana.Job
      end

      assert_raise RuntimeError, "perform/1 not implemented", fn ->
        NoOpJob.perform(%{})
      end
    end

    test "can be overridden with custom implementation" do
      defmodule CustomJob do
        use Hibana.Job

        def perform(data) do
          {:ok, data}
        end
      end

      assert CustomJob.perform(%{key: "value"}) == {:ok, %{key: "value"}}
    end
  end

  describe "enqueue/1" do
    test "returns :ok (async job execution)" do
      defmodule TestJobEnqueue do
        use Hibana.Job

        def perform(data) do
          send(self(), {:performed, data})
        end
      end

      # Start the Worker process so enqueue can call it
      {:ok, _pid} = Hibana.Job.Worker.start_link([])

      # Note: This will spawn a process that performs the job
      # The job runs asynchronously via spawn
      result = TestJobEnqueue.enqueue(%{test: "data"})
      assert result == :ok

      # Job runs asynchronously in a spawned process
      Process.sleep(100)
    end
  end

  describe "custom queue name" do
    test "accepts custom queue option" do
      defmodule CustomQueueJob do
        use Hibana.Job, queue: :my_custom_queue
      end

      assert function_exported?(CustomQueueJob, :perform, 1)
      assert function_exported?(CustomQueueJob, :enqueue, 1)
    end
  end

  describe "Worker" do
    test "Worker module exists" do
      assert Code.ensure_loaded?(Hibana.Job.Worker)
    end

    test "Worker has start_link/1" do
      Code.ensure_loaded!(Hibana.Job.Worker)
      assert function_exported?(Hibana.Job.Worker, :start_link, 1)
    end

    test "Worker has enqueue/2" do
      Code.ensure_loaded!(Hibana.Job.Worker)
      assert function_exported?(Hibana.Job.Worker, :enqueue, 2)
    end
  end
end
