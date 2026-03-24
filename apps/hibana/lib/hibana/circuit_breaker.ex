defmodule Hibana.CircuitBreaker do
  @moduledoc """
  Circuit breaker for external service calls. Prevents cascading failures
  by stopping calls to failing services.

  ## States
  - `:closed` - Normal operation, calls pass through
  - `:open` - Service is down, calls fail immediately
  - `:half_open` - Testing if service recovered

  ## Usage

      # Start a circuit breaker
      Hibana.CircuitBreaker.start_link(
        name: :payment_api,
        threshold: 5,        # failures before opening
        timeout: 30_000,     # ms before trying half-open
        reset_timeout: 60_000 # ms before full reset
      )

      # Use it
      case Hibana.CircuitBreaker.call(:payment_api, fn ->
        HTTPClient.post("https://api.stripe.com/charge", body)
      end) do
        {:ok, result} -> handle_success(result)
        {:error, :circuit_open} -> handle_fallback()
        {:error, reason} -> handle_error(reason)
      end
  """

  use GenServer

  defstruct [
    :name,
    :state,
    :failure_count,
    :threshold,
    :timeout,
    :reset_timeout,
    :last_failure,
    :success_count
  ]

  @doc """
  Starts a circuit breaker process with the given options.

  ## Parameters

    - `opts` - Keyword list of options:
      - `:name` - Process name (required, used for `GenServer` registration)
      - `:threshold` - Number of failures before opening the circuit (default: `5`)
      - `:timeout` - Time in ms before trying half-open after opening (default: `30_000`)
      - `:reset_timeout` - Time in ms before full reset (default: `60_000`)

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      Hibana.CircuitBreaker.start_link(name: :payment_api, threshold: 5, timeout: 30_000)
      ```
  """
  def start_link(opts) do
    name = Keyword.fetch!(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  def init(opts) do
    state = %__MODULE__{
      name: Keyword.fetch!(opts, :name),
      state: :closed,
      failure_count: 0,
      success_count: 0,
      threshold: Keyword.get(opts, :threshold, 5),
      timeout: Keyword.get(opts, :timeout, 30_000),
      reset_timeout: Keyword.get(opts, :reset_timeout, 60_000),
      last_failure: nil
    }

    {:ok, state}
  end

  @doc """
  Executes a function through the circuit breaker.

  If the circuit is closed, the function runs normally. If open, returns
  `{:error, :circuit_open}` immediately without calling the function.
  In half-open state, allows the call through as a test.

  ## Parameters

    - `name` - The registered circuit breaker name
    - `fun` - A zero-arity function to execute

  ## Returns

    - `{:ok, result}` - The function succeeded
    - `{:error, :circuit_open}` - The circuit is open, call rejected
    - `{:error, reason}` - The function raised or threw an error

  ## Examples

      ```elixir
      case Hibana.CircuitBreaker.call(:payment_api, fn -> HTTPClient.post(url, body) end) do
        {:ok, response} -> handle_response(response)
        {:error, :circuit_open} -> fallback_response()
        {:error, reason} -> handle_error(reason)
      end
      ```
  """
  def call(name, fun) do
    GenServer.call(name, {:call, fun}, 30_000)
  end

  @doc """
  Gets the current status of a circuit breaker.

  ## Parameters

    - `name` - The registered circuit breaker name

  ## Returns

  A map with `:state` (`:closed`, `:open`, or `:half_open`), `:failure_count`,
  `:success_count`, and `:threshold`.

  ## Examples

      ```elixir
      Hibana.CircuitBreaker.status(:payment_api)
      # => %{state: :closed, failure_count: 0, success_count: 5, threshold: 5}
      ```
  """
  def status(name) do
    GenServer.call(name, :status)
  end

  @doc """
  Manually resets the circuit breaker to the closed state.

  Clears failure and success counters.

  ## Parameters

    - `name` - The registered circuit breaker name

  ## Returns

  `:ok`

  ## Examples

      ```elixir
      Hibana.CircuitBreaker.reset(:payment_api)
      ```
  """
  def reset(name) do
    GenServer.call(name, :reset)
  end

  def handle_call({:call, fun}, _from, state) do
    case state.state do
      :open ->
        if time_elapsed?(state.last_failure, state.timeout) do
          # Try half-open
          try_call(fun, %{state | state: :half_open, success_count: 0})
        else
          {:reply, {:error, :circuit_open}, state}
        end

      :half_open ->
        try_call(fun, state)

      :closed ->
        try_call(fun, state)
    end
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       state: state.state,
       failure_count: state.failure_count,
       success_count: state.success_count,
       threshold: state.threshold
     }, state}
  end

  def handle_call(:reset, _from, state) do
    {:reply, :ok, %{state | state: :closed, failure_count: 0, success_count: 0}}
  end

  def handle_info(:attempt_reset, state) do
    if state.state == :open do
      {:noreply, %{state | state: :half_open, success_count: 0}}
    else
      {:noreply, state}
    end
  end

  defp try_call(fun, state) do
    try do
      result = fun.()
      new_state = handle_success_result(state)
      {:reply, {:ok, result}, new_state}
    rescue
      e ->
        new_state = handle_failure_result(state)
        {:reply, {:error, e}, new_state}
    catch
      :exit, reason ->
        new_state = handle_failure_result(state)
        {:reply, {:error, reason}, new_state}

      :throw, value ->
        new_state = handle_failure_result(state)
        {:reply, {:error, {:throw, value}}, new_state}
    end
  end

  defp handle_success_result(state) do
    case state.state do
      :half_open ->
        new_count = state.success_count + 1

        if new_count >= 3 do
          %{state | state: :closed, failure_count: 0, success_count: 0}
        else
          %{state | success_count: new_count}
        end

      _ ->
        %{state | success_count: state.success_count + 1}
    end
  end

  defp handle_failure_result(state) do
    new_count = state.failure_count + 1
    now = System.monotonic_time(:millisecond)

    if new_count >= state.threshold do
      Process.send_after(self(), :attempt_reset, state.timeout)
      %{state | state: :open, failure_count: new_count, success_count: 0, last_failure: now}
    else
      %{state | failure_count: new_count, last_failure: now}
    end
  end

  defp time_elapsed?(nil, _timeout), do: true

  defp time_elapsed?(last, timeout) do
    System.monotonic_time(:millisecond) - last >= timeout
  end

  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]},
      type: :worker
    }
  end
end
