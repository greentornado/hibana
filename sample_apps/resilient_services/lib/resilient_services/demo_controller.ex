defmodule ResilientServices.DemoController do
  @moduledoc """
  Controller for demonstrating failure and recovery scenarios.
  """
  use Hibana.Controller

  def simulate_failure(conn) do
    # Simulate a failure scenario
    json(conn, %{
      status: "failure_simulated",
      scenario: "failure",
      message: "Simulating external API failure",
      circuit_state: Hibana.CircuitBreaker.status(:external_api),
      recommendation: "Watch circuit breaker transition to OPEN after 5 failures"
    })
  end

  def simulate_recovery(conn) do
    # Simulate recovery
    Hibana.CircuitBreaker.reset(:external_api)

    json(conn, %{
      status: "recovery_simulated",
      scenario: "recovery",
      message: "Circuit breaker reset",
      circuit_state: Hibana.CircuitBreaker.status(:external_api),
      recommendation: "Circuit is now CLOSED and ready for requests"
    })
  end
end
