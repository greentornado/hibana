defmodule ResilientServices.CircuitController do
  @moduledoc """
  Controller for CircuitBreaker demonstration endpoints.
  """
  use Hibana.Controller

  def status(conn) do
    status = Hibana.CircuitBreaker.status(:external_api)
    json(conn, %{circuit_breakers: [status]})
  end

  def call_api(conn) do
    # Simulate external API call through circuit breaker
    result =
      Hibana.CircuitBreaker.call(:external_api, fn ->
        # Simulate API call that might fail
        if :rand.uniform(10) > 7 do
          {:error, :service_unavailable}
        else
          {:ok, %{data: "API response", timestamp: System.system_time(:second)}}
        end
      end)

    case result do
      {:ok, data} ->
        json(conn, %{status: "success", data: data})

      {:error, :circuit_open} ->
        conn
        |> Plug.Conn.put_status(503)
        |> json(%{status: "error", message: "Circuit breaker is OPEN"})

      {:error, reason} ->
        conn
        |> Plug.Conn.put_status(500)
        |> json(%{status: "error", message: inspect(reason)})
    end
  end

  def trip_circuit(conn) do
    # Trip the circuit by making multiple failing calls
    # The circuit breaker will transition to open after threshold failures
    threshold = 5

    # Simulate failures to trip the circuit
    for _ <- 1..threshold do
      Hibana.CircuitBreaker.call(:external_api, fn ->
        {:error, :simulated_failure}
      end)
    end

    # Get the current status after failures
    status = Hibana.CircuitBreaker.status(:external_api)

    json(conn, %{
      status: "tripped",
      message: "Circuit breaker manually opened",
      circuit_state: status.state
    })
  end

  def reset_circuit(conn) do
    # Reset the circuit
    Hibana.CircuitBreaker.reset(:external_api)
    json(conn, %{status: "reset", message: "Circuit breaker reset to closed"})
  end
end
