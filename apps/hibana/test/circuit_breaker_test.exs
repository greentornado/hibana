defmodule Hibana.CircuitBreakerTest do
  use ExUnit.Case, async: false

  alias Hibana.CircuitBreaker

  setup do
    name = :"cb_test_#{:erlang.unique_integer([:positive])}"
    {:ok, pid} = CircuitBreaker.start_link(name: name, threshold: 3, timeout: 100)
    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{name: name, pid: pid}
  end

  test "start_link starts the circuit breaker", %{pid: pid} do
    assert Process.alive?(pid)
  end

  test "call succeeds in closed state", %{name: name} do
    assert {:ok, 42} = CircuitBreaker.call(name, fn -> 42 end)
  end

  test "call returns function result", %{name: name} do
    assert {:ok, "hello"} = CircuitBreaker.call(name, fn -> "hello" end)
  end

  test "status returns closed state initially", %{name: name} do
    status = CircuitBreaker.status(name)
    assert status.state == :closed
    assert status.failure_count == 0
    assert status.threshold == 3
  end

  test "failures increment counter", %{name: name} do
    CircuitBreaker.call(name, fn -> raise "boom" end)
    status = CircuitBreaker.status(name)
    assert status.failure_count == 1
    assert status.state == :closed
  end

  test "circuit opens after threshold failures", %{name: name} do
    for _ <- 1..3 do
      CircuitBreaker.call(name, fn -> raise "boom" end)
    end

    status = CircuitBreaker.status(name)
    assert status.state == :open
    assert status.failure_count == 3
  end

  test "returns circuit_open error when open", %{name: name} do
    for _ <- 1..3 do
      CircuitBreaker.call(name, fn -> raise "boom" end)
    end

    assert {:error, :circuit_open} = CircuitBreaker.call(name, fn -> :ok end)
  end

  test "reset/1 resets the circuit breaker", %{name: name} do
    for _ <- 1..3 do
      CircuitBreaker.call(name, fn -> raise "boom" end)
    end

    assert CircuitBreaker.status(name).state == :open
    assert :ok = CircuitBreaker.reset(name)

    status = CircuitBreaker.status(name)
    assert status.state == :closed
    assert status.failure_count == 0
  end

  test "success count increments on successful calls", %{name: name} do
    CircuitBreaker.call(name, fn -> :ok end)
    CircuitBreaker.call(name, fn -> :ok end)

    status = CircuitBreaker.status(name)
    assert status.success_count == 2
  end

  test "circuit transitions to half_open after timeout", %{name: name} do
    for _ <- 1..3 do
      CircuitBreaker.call(name, fn -> raise "boom" end)
    end

    assert CircuitBreaker.status(name).state == :open

    # Wait for timeout to trigger half_open via :attempt_reset message
    Process.sleep(150)

    status = CircuitBreaker.status(name)
    assert status.state == :half_open
  end

  test "call returns error tuple on exception", %{name: name} do
    {:error, error} = CircuitBreaker.call(name, fn -> raise "test error" end)
    assert %RuntimeError{message: "test error"} = error
  end
end
