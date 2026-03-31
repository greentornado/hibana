defmodule Hibana.QueueJobMacroTest do
  @moduledoc """
  Tests to force Hibana.Queue.Job macro execution for coverage.
  """
  use ExUnit.Case, async: false

  # Define test modules at compile time
  defmodule TestQueueJob1 do
    use Hibana.Queue.Job

    def perform(args) do
      send(args[:test_pid], {:queue_job_done, args[:data]})
      :ok
    end
  end

  defmodule TestQueueJob2 do
    use Hibana.Queue.Job
    # No perform implementation - uses default
  end

  describe "Queue.Job macro execution" do
    test "__using__ generates perform/1 callback" do
      assert function_exported?(TestQueueJob1, :perform, 1)
    end

    test "__using__ generates enqueue/1 function" do
      assert function_exported?(TestQueueJob1, :enqueue, 1)
      assert function_exported?(TestQueueJob1, :enqueue, 2)
    end

    test "__using__ generates enqueue_at/2 function" do
      assert function_exported?(TestQueueJob1, :enqueue_at, 2)
      assert function_exported?(TestQueueJob1, :enqueue_at, 3)
    end

    test "default perform/1 raises" do
      assert_raise RuntimeError, "perform/1 must be implemented", fn ->
        TestQueueJob2.perform(%{})
      end
    end

    @tag :skip
    test "enqueue function works with Queue" do
      {:ok, _} = Hibana.Queue.start_link(name: Hibana.Queue)

      result = TestQueueJob1.enqueue(%{test_pid: self(), data: 123})
      assert result == :ok

      # Wait for job execution (may take some time)
      assert_receive {:queue_job_done, 123}, 5000

      GenServer.stop(Hibana.Queue)
    end

    @tag :skip
    test "enqueue_at function works with Queue" do
      {:ok, _} = Hibana.Queue.start_link(name: Hibana.Queue)

      future_time = System.system_time(:second) + 1
      result = TestQueueJob1.enqueue_at(%{test_pid: self(), data: 999}, future_time)
      assert result == :ok

      GenServer.stop(Hibana.Queue)
    end
  end
end
