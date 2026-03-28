defmodule ResilientServices.ResilienceController do
  @moduledoc """
  Main controller showing resilience patterns overview.
  """
  use Hibana.Controller

  def index(conn, _params) do
    json(conn, %{
      app: "ResilientServices",
      description: "CircuitBreaker + PersistentQueue resilience patterns",
      current_node: node() |> to_string(),
      features: [
        "Circuit Breaker pattern for external API protection",
        "PersistentQueue with disk spillover for millions of jobs",
        "Automatic retry with exponential backoff",
        "Graceful degradation during failures",
        "Queue monitoring and statistics"
      ],
      endpoints: [
        %{
          method: "GET",
          path: "/resilience/stats",
          description: "Combined circuit + queue stats"
        },
        %{method: "GET", path: "/circuit/status", description: "Circuit breaker state"},
        %{method: "POST", path: "/circuit/call", description: "Call API through circuit breaker"},
        %{method: "POST", path: "/circuit/trip", description: "Manually trip circuit"},
        %{method: "POST", path: "/circuit/reset", description: "Reset circuit breaker"},
        %{method: "POST", path: "/jobs", description: "Submit job to queue"},
        %{method: "GET", path: "/jobs", description: "List queued jobs"},
        %{method: "GET", path: "/jobs/stats", description: "Queue statistics"},
        %{method: "POST", path: "/jobs/process", description: "Process pending jobs"},
        %{method: "GET", path: "/demo/failure", description: "Simulate failure scenario"},
        %{method: "GET", path: "/demo/recovery", description: "Simulate recovery"}
      ],
      demo_flow: [
        "1. Check /circuit/status - should be 'closed'",
        "2. POST /circuit/call - make API calls",
        "3. After 5 failures, circuit opens - calls return :circuit_open",
        "4. Wait 30s - circuit enters 'half_open'",
        "5. POST /jobs - submit background jobs to queue",
        "6. Watch jobs persist across restarts (stored on disk)"
      ]
    })
  end

  def stats(conn, _params) do
    # Get circuit breaker status
    circuit_status = Hibana.CircuitBreaker.status(:external_api)

    # Get queue stats (simplified)
    queue_stats = %{
      # Would get from actual queue
      memory_jobs: 0,
      disk_jobs: 0,
      in_flight: 0,
      processed: 0
    }

    json(conn, %{
      circuit_breaker: circuit_status,
      persistent_queue: queue_stats,
      resilience_score: calculate_resilience_score(circuit_status),
      healthy: circuit_status.state == :closed
    })
  end

  defp calculate_resilience_score(%{state: :closed}), do: 100
  defp calculate_resilience_score(%{state: :half_open}), do: 50
  defp calculate_resilience_score(%{state: :open}), do: 0
end
