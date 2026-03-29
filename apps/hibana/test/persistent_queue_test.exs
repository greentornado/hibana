defmodule Hibana.PersistentQueueTest do
  use ExUnit.Case

  alias Hibana.PersistentQueue

  defmodule TestWorker do
    def perform(args) do
      send(args[:test_pid], {:job_done, args[:value]})
      :ok
    end
  end

  setup do
    queue_name = :"test_queue_#{:rand.uniform(10000)}"
    tmp_dir = Path.join(System.tmp_dir!(), "pq_test_#{:rand.uniform(10000)}")
    File.mkdir_p!(tmp_dir)

    {:ok, pid} =
      PersistentQueue.start_link(
        name: queue_name,
        disk_path: tmp_dir,
        max_memory_items: 100,
        concurrency: 2,
        poll_interval: 100
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

  describe "enqueue/4" do
    test "successfully enqueues job", %{queue: queue} do
      test_pid = self()

      {:ok, job_id} =
        PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 42}, priority: 5)

      assert is_binary(job_id)

      # Wait for job to be processed
      assert_receive {:job_done, 42}, 2000
    end

    test "assigns unique job id for each enqueue", %{queue: queue} do
      test_pid = self()

      {:ok, id1} = PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 1}, [])
      {:ok, id2} = PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 2}, [])

      assert id1 != id2
    end

    test "supports priority option", %{queue: queue} do
      test_pid = self()

      # Enqueue with different priorities
      {:ok, _} =
        PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 1}, priority: 10)

      {:ok, _} =
        PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 2}, priority: 1)

      # Both jobs should be processed
      assert_receive {:job_done, _}, 2000
      assert_receive {:job_done, _}, 2000
    end

    test "supports delay option", %{queue: queue} do
      test_pid = self()

      start_time = System.monotonic_time(:millisecond)

      {:ok, _} =
        PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 1}, delay: 500)

      # Job should be processed after delay
      assert_receive {:job_done, 1}, 2000

      end_time = System.monotonic_time(:millisecond)
      # Should have been delayed
      assert end_time - start_time >= 400
    end
  end

  describe "stats/1" do
    test "returns queue statistics", %{queue: queue} do
      stats = PersistentQueue.stats(queue)

      assert is_map(stats)
      assert Map.has_key?(stats, :pending)
      assert Map.has_key?(stats, :in_flight)
      assert Map.has_key?(stats, :completed)
      assert Map.has_key?(stats, :failed)
    end
  end

  describe "pause/1 and resume/1" do
    test "pauses and resumes job processing", %{queue: queue} do
      test_pid = self()

      # Pause the queue
      :ok = PersistentQueue.pause(queue)

      # Enqueue a job
      {:ok, _} = PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: 1}, [])

      # Job should not be processed while paused
      refute_receive {:job_done, 1}, 500

      # Resume the queue
      :ok = PersistentQueue.resume(queue)

      # Now job should be processed
      assert_receive {:job_done, 1}, 2000
    end
  end

  describe "clear/1" do
    test "clears all jobs from queue", %{queue: queue, tmp_dir: tmp_dir} do
      test_pid = self()

      # Enqueue some jobs
      for i <- 1..3 do
        {:ok, _} = PersistentQueue.enqueue(queue, TestWorker, %{test_pid: test_pid, value: i}, [])
      end

      # Clear the queue
      :ok = PersistentQueue.clear(queue)

      # Queue should be empty
      stats = PersistentQueue.stats(queue)
      assert stats.pending == 0
      assert stats.disk == 0
    end
  end
end
