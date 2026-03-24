# `Hibana.Plugins.HealthCheck`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/health_check.ex#L1)

Health check endpoint plugin for load balancers and orchestration.

## Features

- Built-in system health checks (memory, processes, uptime)
- Custom health check registration
- Prometheus-compatible response format
- Configurable health endpoint path

## Usage

    # Basic usage (health endpoint at /health)
    plug Hibana.Plugins.HealthCheck

    # With custom path
    plug Hibana.Plugins.HealthCheck, path: "/api/health"

## Response Format

Returns JSON:

    {
      "status": "healthy",
      "timestamp": 1234567890,
      "checks": {
        "memory": "ok",
        "processes": "ok",
        "uptime": "ok"
      }
    }

- HTTP 200: All checks pass
- HTTP 503: One or more checks fail

## Built-in Checks

- **memory** - Checks if memory usage is below threshold
- **processes** - Checks if process count is below threshold
- **uptime** - Always returns :ok

## Custom Checks

Register custom health checks:

    Hibana.Plugins.HealthCheck.register_check(:database, fn ->
      case DB.check_connection() do
        :ok -> :ok
        _ -> :error
      end
    end)

## Options

- `:path` - Health endpoint path (default: `"/health"`)
- `:checks` - List of additional checks to run

## Response Headers

- `x-health-status` - "ok" or "error"
- `content-type` - "application/json"

# `before_send`

# `register_check`

Register a custom health check.

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
