# `Hibana.Queue`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/queue.ex#L1)

Persistent background job queue with GenServer and Erlang processes.

## Usage

    # Define a job
    defmodule SendEmailJob do
      use Hibana.Queue.Job

      def perform(data) do
        IO.puts("Sending email to: #{data[:to]}")
      end
    end

    # Enqueue with delay (in milliseconds)
    SendEmailJob.enqueue(%{to: "user@example.com"}, delay: 5000)

    # Enqueue with retry
    SendEmailJob.enqueue(%{to: "user@example.com"}, retry: 3)

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `clear`

Clear all jobs from queue.

# `enqueue`

Enqueue a job to be processed.

# `enqueue_at`

Enqueue a job to be processed at a specific time.

# `init`

# `start_link`

# `stats`

Get queue statistics.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
