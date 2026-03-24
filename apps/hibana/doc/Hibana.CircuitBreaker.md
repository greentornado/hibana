# `Hibana.CircuitBreaker`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/circuit_breaker.ex#L1)

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

# `call`

Execute a function through the circuit breaker

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `init`

# `reset`

Manually reset the circuit breaker

# `start_link`

# `status`

Get current state

---

*Consult [api-reference.md](api-reference.md) for complete listing*
