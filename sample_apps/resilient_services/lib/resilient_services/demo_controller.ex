defmodule ResilientServices.DemoController do
  @moduledoc """
  Controller for demonstrating failure and recovery scenarios.
  """
  use Hibana.Controller

  def failure(conn) do
    # Simulate a failure scenario
    json(conn, %{
      scenario: "failure",
      message: "Simulating external API failure",
      circuit_state: Hibana.CircuitBreaker.status(:external_api),
      recommendation: "Watch circuit breaker transition to OPEN after 5 failures"
    })
  end

  def recovery(conn) do
    # Simulate recovery
    Hibana.CircuitBreaker.reset(:external_api)

    json(conn, %{
      scenario: "recovery",
      message: "Circuit breaker reset",
      circuit_state: Hibana.CircuitBreaker.status(:external_api),
      recommendation: "Circuit is now CLOSED and ready for requests"
    })
  end

  def external_api(conn) do
    # Demo external API endpoint
    result =
      Hibana.CircuitBreaker.call(:external_api, fn ->
        {:ok, %{service: "external_api", status: "operational"}}
      end)

    case result do
      {:ok, data} ->
        json(conn, data)

      {:error, :circuit_open} ->
        json(conn, %{error: "Service unavailable - circuit open"}, status: 503)

      {:error, reason} ->
        json(conn, %{error: inspect(reason)}, status: 500)
    end
  end

  def queue_processing(conn) do
    # Demo queue processing
    json(conn, %{
      status: "running",
      jobs_in_queue: 0,
      jobs_processing: 0,
      jobs_completed: 0,
      message: "Queue processing demonstration"
    })
  end
end
