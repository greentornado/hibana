defmodule Hibana.QueueTest do
  use ExUnit.Case, async: false

  describe "Job macro" do
    defmodule TestJob do
      use Hibana.Queue.Job

      def perform(data) do
        {:ok, data}
      end
    end

    test "creates enqueue function" do
      assert function_exported?(TestJob, :enqueue, 2)
    end

    test "creates enqueue_at function" do
      assert function_exported?(TestJob, :enqueue_at, 3)
    end
  end
end
