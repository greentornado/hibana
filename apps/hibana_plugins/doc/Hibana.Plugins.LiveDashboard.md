# `Hibana.Plugins.LiveDashboard`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/live_dashboard.ex#L1)

System dashboard plugin for Hibana, similar to Phoenix LiveDashboard.

Provides a dark-themed dashboard with auto-refresh (every 3 seconds) showing:
- System overview (memory, processes, ports, schedulers, uptime)
- Process list (top 100 by memory)
- ETS tables
- Ports
- OTP applications
- Memory allocation details

## Usage

    plug Hibana.Plugins.LiveDashboard, path: "/_dashboard"

## Options

- `:path` - Base URL path for the dashboard (default: `"/_dashboard"`)
- `:auth` - A function `(Plug.Conn.t() -> boolean())` that checks authorization; when `nil`, the dashboard is publicly accessible (default: `nil`)

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
