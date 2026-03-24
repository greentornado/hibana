# `Hibana.PersistentQueue`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/persistent_queue.ex#L1)

High-performance persistent job queue with disk spillover and backpressure.

Supports millions of jobs with automatic disk spillover when memory limits
are reached. Uses DETS for persistence and ETS for hot jobs.

## Usage

    # Start the queue
    {:ok, _pid} = Hibana.PersistentQueue.start_link(
      name: :jobs,
      max_memory_jobs: 10_000,
      data_dir: "priv/queue",
      concurrency: 10
    )

    # Enqueue a job
    Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{user_id: 123})

    # Enqueue with priority (lower = higher priority)
    Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{data: "urgent"}, priority: 0)

    # Enqueue with delay
    Hibana.PersistentQueue.enqueue(:jobs, MyWorker, %{}, delay: 60_000)

    # Get queue stats
    Hibana.PersistentQueue.stats(:jobs)

    # Pause/resume processing
    Hibana.PersistentQueue.pause(:jobs)
    Hibana.PersistentQueue.resume(:jobs)

## Features

- **Disk spillover**: When memory jobs exceed `max_memory_jobs`, older jobs spill to DETS
- **Backpressure**: Returns `{:error, :queue_full}` when disk queue exceeds limits
- **Concurrency control**: Configurable number of concurrent workers
- **Priority queues**: Jobs with lower priority numbers are processed first
- **Retry with exponential backoff**: Failed jobs retry with increasing delays
- **Persistence**: Jobs survive process restarts via DETS
- **Graceful shutdown**: Waits for in-flight jobs before stopping

## Options

- `:name` — Queue name (default: `__MODULE__`)
- `:max_memory_jobs` — Max jobs in ETS before spilling to disk (default: 10_000)
- `:max_disk_jobs` — Max jobs on disk (default: 1_000_000)
- `:data_dir` — Directory for DETS files (default: `"priv/queue"`)
- `:concurrency` — Max concurrent job workers (default: `System.schedulers_online()`)
- `:poll_interval` — How often to check for new jobs in ms (default: 100)

# `child_spec`

Return a child specification for use in a supervision tree.

# `clear`

Clear all jobs from both memory and disk queues.

# `enqueue`

Enqueue a job with the given worker module, args, and options (priority, delay, max_retries).

# `init`

# `pause`

Pause job processing. Existing in-flight jobs will complete.

# `resume`

Resume job processing after a pause.

# `start_link`

Start the persistent queue process with the given options.

# `stats`

Return queue statistics including memory jobs, disk jobs, and in-flight count.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
