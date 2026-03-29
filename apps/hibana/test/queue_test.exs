defmodule Hibana.QueueTest do
  use ExUnit.Case, async: false

  alias Hibana.Queue

  defmodule TestJob do
    use Hibana.Queue.Job

    def perform(data) do
      {:ok, data}
    end
  end

  describe "Job macro" do
    test "creates enqueue function" do
      assert function_exported?(TestJob, :enqueue, 2)
    end

    test "creates enqueue_at function" do
      assert function_exported?(TestJob, :enqueue_at, 3)
    end

    test "perform function returns data" do
      assert TestJob.perform(%{test: "data"}) == {:ok, %{test: "data"}}
    end
  end

  describe "Queue API" do
    test "start_link with default name" do
      {:ok, pid} = Queue.start_link(name: :test_default_queue)
      assert Process.alive?(pid)
      GenServer.stop(pid)
    end

    test "enqueue returns job id" do
      {:ok, pid} = Queue.start_link(name: :test_api_queue)

      defmodule SimpleWorker do
        def perform(_args), do: :ok
      end

      result = Queue.enqueue(SimpleWorker, %{}, [], :test_api_queue)
      assert {:ok, job_id} = result
      assert is_binary(job_id)

      GenServer.stop(pid)
    end
  end
end
