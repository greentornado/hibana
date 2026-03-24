# `Hibana.Plugins.TelemetryDashboard`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/telemetry_dashboard.ex#L1)

Built-in telemetry dashboard showing live metrics via an HTML page.

## Usage

    plug Hibana.Plugins.TelemetryDashboard, path: "/dashboard"

## Dashboard Shows
- Request count, rate, avg duration
- Memory usage, process count
- Node info, uptime
- Queue depth (if PersistentQueue running)

## Options

- `:path` - URL path for the dashboard page (default: `"/dashboard"`)
- `:auth` - A function `(Plug.Conn.t() -> boolean())` that checks authorization; when `nil`, the dashboard is publicly accessible (default: `nil`)

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
