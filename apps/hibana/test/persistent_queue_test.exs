defmodule Hibana.PersistentQueueTest do
  use ExUnit.Case

  alias Hibana.PersistentQueue

  setup do
    queue_name = :"test_queue_#{:rand.uniform(10000)}"
    tmp_dir = Path.join(System.tmp_dir!(), "pq_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(tmp_dir)

    {:ok, pid} =
      PersistentQueue.start_link(
        name: queue_name,
        disk_path: tmp_dir,
        max_memory_items: 100,
        concurrency: 2
      )

    on_exit(fn ->
      try do
        GenServer.stop(pid)
      catch
        _, _ -> :ok
      end

      File.rm_rf!(tmp_dir)
    end)

    {:ok, queue: queue_name, pid: pid, tmp_dir: tmp_dir}
  end

  describe "enqueue/2" do
    test "successfully enqueues job", %{queue: queue} do
      job = %{task: "test", data: "value"}

      :ok = PersistentQueue.enqueue(queue, job)

      # Verify job is in queue
      {:ok, dequeued} = PersistentQueue.dequeue(queue)
      assert dequeued.task == "test"
    end

    test "assigns unique job id", %{queue: queue} do
      job1 = %{task: "job1"}
      job2 = %{task: "job2"}

      :ok = PersistentQueue.enqueue(queue, job1)
      :ok = PersistentQueue.enqueue(queue, job2)

      {:ok, result1} = PersistentQueue.dequeue(queue)
      {:ok, result2} = PersistentQueue.dequeue(queue)

      assert result1.id != result2.id
    end
  end

  describe "dequeue/1" do
    test "returns job when available", %{queue: queue} do
      job = %{task: "test"}
      :ok = PersistentQueue.enqueue(queue, job)

      {:ok, result} = PersistentQueue.dequeue(queue)

      assert result.task == "test"
      assert is_binary(result.id)
      assert result.inserted_at
    end

    test "returns empty when no jobs", %{queue: queue} do
      result = PersistentQueue.dequeue(queue)

      assert result == :empty
    end

    test "respects priority order", %{queue: queue} do
      # Enqueue with different priorities
      :ok = PersistentQueue.enqueue(queue, %{task: "low"}, priority: 10)
      :ok = PersistentQueue.enqueue(queue, %{task: "high"}, priority: 1)
      :ok = PersistentQueue.enqueue(queue, %{task: "medium"}, priority: 5)

      # Should dequeue high priority first
      {:ok, job1} = PersistentQueue.dequeue(queue)
      assert job1.task == "high"

      {:ok, job2} = PersistentQueue.dequeue(queue)
      assert job2.task == "medium"

      {:ok, job3} = PersistentQueue.dequeue(queue)
      assert job3.task == "low"
    end
  end

  describe "ack/2" do
    test "acknowledges job completion", %{queue: queue} do
      job = %{task: "test"}
      :ok = PersistentQueue.enqueue(queue, job)

      {:ok, %{id: job_id}} = PersistentQueue.dequeue(queue)

      :ok = PersistentQueue.ack(queue, job_id)

      # Job should be removed from queue
      result = PersistentQueue.dequeue(queue)
      assert result == :empty
    end
  end

  describe "nack/3" do
    test "requeues failed job with retry", %{queue: queue} do
      job = %{task: "test"}
      :ok = PersistentQueue.enqueue(queue, job)

      {:ok, %{id: job_id}} = PersistentQueue.dequeue(queue)

      :ok = PersistentQueue.nack(queue, job_id, error: "failed")

      # Job should be back in queue
      {:ok, result} = PersistentQueue.dequeue(queue)
      assert result.task == "test"
    end
  end

  describe "stats/1" do
    test "returns queue statistics", %{queue: queue} do
      stats = PersistentQueue.stats(queue)

      assert is_map(stats)
      assert Map.has_key?(stats, :pending)
      assert Map.has_key?(stats, :in_flight)
      assert Map.has_key?(stats, :completed)
    end
  end
end
