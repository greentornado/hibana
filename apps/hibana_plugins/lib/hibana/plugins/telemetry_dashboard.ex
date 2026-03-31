defmodule Hibana.Plugins.TelemetryDashboard do
  @moduledoc """
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
  - `:auth` - A function `(Plug.Conn.t() -> boolean())` that checks authorization. 
    **Security Note:** In production, you MUST configure authentication. The dashboard
    exposes sensitive system information (memory, processes, cluster nodes, ETS tables).
    When `auth` is not provided, access is denied by default. Set to `nil` only for
    development, or provide a function that validates admin credentials.
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  @impl true
  def init(opts) do
    %{
      path: Keyword.get(opts, :path, "/dashboard"),
      auth: Keyword.get(opts, :auth, :deny)
    }
  end

  @impl true
  def call(conn, %{path: path, auth: auth}) do
    if conn.request_path == path and conn.method == "GET" do
      if auth == :deny do
        # Default deny - must configure auth in production
        Logger.warning(
          "[Hibana.Plugins.TelemetryDashboard] Dashboard access denied. Configure :auth option to enable. " <>
            "Example: plug Hibana.Plugins.TelemetryDashboard, auth: fn conn -> verify_admin_token(conn) end"
        )

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(403, "Forbidden: Dashboard authentication not configured")
        |> halt()
      else
        if auth && !auth.(conn) do
          conn |> send_resp(401, "Unauthorized") |> halt()
        else
          render_dashboard(conn)
        end
      end
    else
      conn
    end
  end

  defp render_dashboard(conn) do
    mem = :erlang.memory()
    uptime = :erlang.statistics(:wall_clock) |> elem(0) |> div(1000)
    process_count = length(Process.list())
    scheduler_count = System.schedulers_online()
    node_name = Node.self()
    connected = Node.list()
    otp_release = :erlang.system_info(:otp_release) |> to_string()

    metrics =
      try do
        case :ets.lookup(:metrics, :requests_total) do
          [{_, count}] -> count
          _ -> 0
        end
      rescue
        _ -> 0
      end

    html = """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Hibana Dashboard</title>
      <meta charset="utf-8">
      <meta http-equiv="refresh" content="5">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f0f23; color: #ccc; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 24px 32px; }
        .header h1 { color: white; font-size: 22px; }
        .header p { color: rgba(255,255,255,0.7); font-size: 13px; margin-top: 4px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 1fr)); gap: 16px; padding: 24px 32px; }
        .card { background: #1a1a36; border-radius: 8px; padding: 20px; border: 1px solid #2a2a4a; }
        .card .label { font-size: 12px; color: #888; text-transform: uppercase; letter-spacing: 1px; }
        .card .value { font-size: 28px; font-weight: 700; color: #fff; margin-top: 8px; }
        .card .sub { font-size: 12px; color: #666; margin-top: 4px; }
        .section { padding: 0 32px 24px; }
        .section h2 { font-size: 14px; color: #888; text-transform: uppercase; margin-bottom: 12px; }
        table { width: 100%; border-collapse: collapse; }
        td { padding: 8px 12px; border-bottom: 1px solid #2a2a4a; font-size: 13px; }
        td:first-child { color: #888; }
        .green { color: #2ecc71; }
        .blue { color: #3498db; }
        .yellow { color: #f1c40f; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Hibana Dashboard</h1>
        <p>Node: #{node_name} | OTP #{otp_release} | Uptime: #{format_uptime(uptime)}</p>
      </div>
      <div class="grid">
        <div class="card">
          <div class="label">Total Requests</div>
          <div class="value blue">#{metrics}</div>
        </div>
        <div class="card">
          <div class="label">Memory (Total)</div>
          <div class="value">#{format_bytes(mem[:total])}</div>
          <div class="sub">Processes: #{format_bytes(mem[:processes])} | Binary: #{format_bytes(mem[:binary])}</div>
        </div>
        <div class="card">
          <div class="label">Processes</div>
          <div class="value yellow">#{process_count}</div>
          <div class="sub">Schedulers: #{scheduler_count}</div>
        </div>
        <div class="card">
          <div class="label">Cluster Nodes</div>
          <div class="value green">#{length(connected) + 1}</div>
          <div class="sub">#{Enum.join([node_name | connected], ", ")}</div>
        </div>
        <div class="card">
          <div class="label">Atoms</div>
          <div class="value">#{:erlang.system_info(:atom_count)}</div>
          <div class="sub">Limit: #{:erlang.system_info(:atom_limit)}</div>
        </div>
        <div class="card">
          <div class="label">ETS Tables</div>
          <div class="value">#{length(:ets.all())}</div>
        </div>
      </div>
      <div class="section">
        <h2>Memory Breakdown</h2>
        <table>
          #{Enum.map_join(mem, fn {k, v} -> "<tr><td>#{k}</td><td>#{format_bytes(v)}</td></tr>" end)}
        </table>
      </div>
    </body>
    </html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
    |> halt()
  end

  defp format_uptime(seconds) do
    days = div(seconds, 86400)
    hours = div(rem(seconds, 86400), 3600)
    mins = div(rem(seconds, 3600), 60)
    secs = rem(seconds, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{mins}m"
      hours > 0 -> "#{hours}h #{mins}m #{secs}s"
      mins > 0 -> "#{mins}m #{secs}s"
      true -> "#{secs}s"
    end
  end

  defp format_bytes(bytes) when bytes >= 1_073_741_824,
    do: "#{Float.round(bytes / 1_073_741_824, 1)} GB"

  defp format_bytes(bytes) when bytes >= 1_048_576, do: "#{Float.round(bytes / 1_048_576, 1)} MB"
  defp format_bytes(bytes) when bytes >= 1024, do: "#{Float.round(bytes / 1024, 1)} KB"
  defp format_bytes(bytes), do: "#{bytes} B"
end
