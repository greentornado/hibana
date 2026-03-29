defmodule ResilientServices.CircuitController do
  @moduledoc """
  Controller for CircuitBreaker demonstration endpoints.
  """
  use Hibana.Controller

  def status(conn) do
    status = Hibana.CircuitBreaker.status(:external_api)
    json(conn, status)
  end

  def call(conn) do
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
        json(conn, %{status: "error", message: "Circuit breaker is OPEN"}, status: 503)

      {:error, reason} ->
        json(conn, %{status: "error", message: inspect(reason)}, status: 500)
    end
  end

  def trip(conn) do
    # Manually trip the circuit
    Hibana.CircuitBreaker.open(:external_api)
    json(conn, %{status: "tripped", message: "Circuit breaker manually opened"})
  end

  def reset(conn) do
    # Reset the circuit
    Hibana.CircuitBreaker.reset(:external_api)
    json(conn, %{status: "reset", message: "Circuit breaker reset to closed"})
  end
end
