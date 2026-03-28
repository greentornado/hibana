defmodule ResilientServices.Application do
  @moduledoc """
  Application with CircuitBreaker and PersistentQueue for resilience patterns.
  """
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Circuit breaker for external API calls
      {Hibana.CircuitBreaker,
       name: :external_api, threshold: 5, timeout: 30_000, reset_timeout: 60_000},

      # Persistent queue for background jobs (handles millions of jobs, spills to disk)
      {Hibana.PersistentQueue, name: :job_queue, max_memory_jobs: 1000, max_disk_jobs: 100_000},

      # Endpoint
      ResilientServices.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ResilientServices.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
