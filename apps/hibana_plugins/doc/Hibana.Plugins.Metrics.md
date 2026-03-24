# `Hibana.Plugins.Metrics`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/metrics.ex#L1)

Metrics and Telemetry plugin for monitoring and observability.

## Features

- Request duration tracking via :telemetry
- Request counting by method, path, and status
- Prometheus-compatible metrics endpoint
- Zero-configuration defaults

## Usage

    # Basic usage (metrics at /metrics)
    plug Hibana.Plugins.Metrics

    # With custom endpoint
    plug Hibana.Plugins.Metrics, endpoint: "/admin/metrics"

## Telemetry Events

Emits the following :telemetry events:

### [:hibana, :request, :duration]
Fired on each request completion.

    :telemetry.execute(
      [:hibana, :request, :duration],
      %{duration: 123},
      %{method: "GET", path: "/users", status: 200}
    )

### [:hibana, :request, :total]
Counter incremented on each request.

    :telemetry.execute(
      [:hibana, :request, :total],
      %{count: 1},
      %{method: "GET", path: "/users", status: 200}
    )

## Prometheus Endpoint

GET /metrics returns Prometheus-formatted metrics:

    # HELP hibana_requests_total Total requests
    # TYPE hibana_requests_total counter
    hibana_requests_total 1234

    # HELP hibana_request_duration_ms Request duration
    # TYPE hibana_request_duration_ms histogram
    hibana_request_duration_ms_count 1234

## Options

- `:enabled` - Enable/disable metrics (default: `true`)
- `:endpoint` - Metrics endpoint path (default: `"/metrics"`)

## Integration with Prometheus

Can be scraped by Prometheus:

    scrape_configs:
      - job_name: 'hibana'
        static_configs:
          - targets: ['localhost:4000']
        metrics_path: '/metrics'

# `before_send`

# `setup`

# `start_link`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
