defmodule Hibana.Plugins.LiveDashboard do
  @moduledoc """
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
  - `:auth` - A function `(Plug.Conn.t() -> boolean())` that checks authorization.
    **Security Note:** In production, you MUST configure authentication. The dashboard
    exposes sensitive system information (memory, processes, ETS tables, cluster topology).
    When `auth` is not provided, access is denied by default. Set to `nil` only for
    development, or provide a function that validates admin credentials.
  """

  use Hibana.Plugin

  import Plug.Conn
  require Logger

  @default_path "/_dashboard"

  @impl true
  def init(opts) do
    %{
      path: Keyword.get(opts, :path, @default_path),
      auth: Keyword.get(opts, :auth, :deny)
    }
  end

  @impl true
  def call(conn, %{path: base_path, auth: auth}) do
    cond do
      conn.request_path == base_path or String.starts_with?(conn.request_path, base_path <> "/") ->
        if auth == :deny do
          # Default deny - must configure auth in production
          Logger.warning(
            "[Hibana.Plugins.LiveDashboard] Dashboard access denied. Configure :auth option to enable. " <>
              "Example: plug Hibana.Plugins.LiveDashboard, auth: fn conn -> verify_admin_token(conn) end"
          )

          conn
          |> put_resp_content_type("text/plain")
          |> send_resp(403, "Forbidden: Dashboard authentication not configured")
          |> halt()
        else
          if auth && !auth.(conn) do
            conn |> send_resp(401, "Unauthorized") |> halt()
          else
            if conn.request_path == base_path do
              redirect_to(conn, "#{base_path}/overview")
            else
              page = conn.request_path |> String.replace_prefix(base_path <> "/", "")
              serve_page(conn, base_path, page)
            end
          end
        end

      true ->
        conn
    end
  end

  defp redirect_to(conn, path) do
    conn
    |> put_resp_header("location", path)
    |> send_resp(302, "")
    |> halt()
  end

  defp serve_page(conn, base_path, page) do
    content =
      case page do
        "overview" -> render_overview()
        "processes" -> render_processes()
        "ets" -> render_ets()
        "ports" -> render_ports()
        "applications" -> render_applications()
        "memory" -> render_memory()
        _ -> "<h2>Page not found</h2>"
      end

    tabs = [
      {"overview", "Overview"},
      {"processes", "Processes"},
      {"ets", "ETS"},
      {"ports", "Ports"},
      {"applications", "Applications"},
      {"memory", "Memory"}
    ]

    html = render_layout(base_path, page, tabs, content)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
    |> halt()
  end

  # ── Layout ──

  defp render_layout(base_path, active_page, tabs, content) do
    tab_html =
      tabs
      |> Enum.map(fn {slug, label} ->
        active = if slug == active_page, do: "active", else: ""
        ~s(<a class="tab #{active}" href="#{base_path}/#{slug}">#{label}</a>)
      end)
      |> Enum.join("\n        ")

    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="utf-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Hibana Dashboard</title>
      <meta http-equiv="refresh" content="3">
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; background: #0d1117; color: #c9d1d9; }
        .header { background: #161b22; border-bottom: 1px solid #30363d; padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; }
        .header h1 { font-size: 20px; color: #58a6ff; }
        .header .uptime { font-size: 13px; color: #8b949e; }
        .tabs { background: #161b22; border-bottom: 1px solid #30363d; padding: 0 24px; display: flex; gap: 0; }
        .tab { padding: 12px 16px; color: #8b949e; text-decoration: none; font-size: 14px; border-bottom: 2px solid transparent; }
        .tab:hover { color: #c9d1d9; }
        .tab.active { color: #58a6ff; border-bottom-color: #f78166; }
        .content { padding: 24px; max-width: 1400px; margin: 0 auto; }
        .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 16px; margin-bottom: 24px; }
        .card { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 16px; }
        .card .label { font-size: 12px; color: #8b949e; text-transform: uppercase; margin-bottom: 4px; }
        .card .value { font-size: 24px; font-weight: 600; color: #58a6ff; }
        .card .sub { font-size: 12px; color: #8b949e; margin-top: 4px; }
        table { width: 100%; border-collapse: collapse; background: #161b22; border: 1px solid #30363d; border-radius: 6px; overflow: hidden; }
        th { background: #21262d; text-align: left; padding: 10px 12px; font-size: 12px; color: #8b949e; text-transform: uppercase; border-bottom: 1px solid #30363d; }
        td { padding: 8px 12px; font-size: 13px; border-bottom: 1px solid #21262d; font-family: 'SF Mono', 'Fira Code', monospace; }
        tr:hover { background: #1c2128; }
        .bar-container { background: #21262d; border-radius: 3px; height: 8px; width: 100%; margin-top: 8px; }
        .bar { height: 8px; border-radius: 3px; background: #238636; }
        .bar.warn { background: #d29922; }
        .bar.danger { background: #f85149; }
        h2 { font-size: 16px; color: #c9d1d9; margin-bottom: 16px; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Hibana Dashboard</h1>
        <span class="uptime">Uptime: #{format_uptime()}</span>
      </div>
      <div class="tabs">
        #{tab_html}
      </div>
      <div class="content">
        #{content}
      </div>
    </body>
    </html>
    """
  end

  # ── Overview page ──

  defp render_overview do
    mem = :erlang.memory()
    total_mem = mem[:total]
    proc_mem = mem[:processes]
    ets_mem = mem[:ets]
    atom_mem = mem[:atom]
    bin_mem = mem[:binary]
    sys_info = :erlang.system_info(:system_version) |> to_string()
    schedulers = :erlang.system_info(:schedulers_online)
    process_count = :erlang.system_info(:process_count)
    process_limit = :erlang.system_info(:process_limit)
    port_count = :erlang.system_info(:port_count)
    port_limit = :erlang.system_info(:port_limit)
    atom_count = :erlang.system_info(:atom_count)
    atom_limit = :erlang.system_info(:atom_limit)

    proc_pct = Float.round(process_count / process_limit * 100, 1)
    port_pct = Float.round(port_count / port_limit * 100, 1)
    atom_pct = Float.round(atom_count / atom_limit * 100, 1)

    nodes =
      case Node.list() do
        [] -> "standalone"
        list -> Enum.join(["#{Node.self()}" | Enum.map(list, &to_string/1)], ", ")
      end

    """
    <p style="font-size:12px; color:#8b949e; margin-bottom:16px;">#{html_escape(sys_info)}</p>
    <div class="grid">
      <div class="card">
        <div class="label">Total Memory</div>
        <div class="value">#{format_bytes(total_mem)}</div>
      </div>
      <div class="card">
        <div class="label">Processes</div>
        <div class="value">#{format_number(process_count)}</div>
        <div class="sub">Limit: #{format_number(process_limit)}</div>
        #{render_bar(proc_pct)}
      </div>
      <div class="card">
        <div class="label">Ports</div>
        <div class="value">#{format_number(port_count)}</div>
        <div class="sub">Limit: #{format_number(port_limit)}</div>
        #{render_bar(port_pct)}
      </div>
      <div class="card">
        <div class="label">Schedulers</div>
        <div class="value">#{schedulers}</div>
      </div>
      <div class="card">
        <div class="label">Atoms</div>
        <div class="value">#{format_number(atom_count)}</div>
        <div class="sub">Limit: #{format_number(atom_limit)}</div>
        #{render_bar(atom_pct)}
      </div>
      <div class="card">
        <div class="label">Cluster Nodes</div>
        <div class="value" style="font-size:14px;">#{html_escape(nodes)}</div>
      </div>
    </div>
    <h2>Memory Breakdown</h2>
    <div class="grid">
      <div class="card">
        <div class="label">Process Memory</div>
        <div class="value">#{format_bytes(proc_mem)}</div>
        #{render_bar(Float.round(proc_mem / total_mem * 100, 1))}
      </div>
      <div class="card">
        <div class="label">ETS Memory</div>
        <div class="value">#{format_bytes(ets_mem)}</div>
        #{render_bar(Float.round(ets_mem / total_mem * 100, 1))}
      </div>
      <div class="card">
        <div class="label">Atom Memory</div>
        <div class="value">#{format_bytes(atom_mem)}</div>
        #{render_bar(Float.round(atom_mem / total_mem * 100, 1))}
      </div>
      <div class="card">
        <div class="label">Binary Memory</div>
        <div class="value">#{format_bytes(bin_mem)}</div>
        #{render_bar(Float.round(bin_mem / total_mem * 100, 1))}
      </div>
    </div>
    """
  end

  # ── Processes page ──

  defp render_processes do
    process_count = :erlang.system_info(:process_count)

    # Safety limit: skip detailed enumeration if too many processes
    if process_count > 10_000 do
      """
      <h2>Processes</h2>
      <div style="padding: 20px; background: #161b22; border: 1px solid #30363d; border-radius: 6px;">
        <p style="color: #d29922;">⚠️ Process enumeration skipped: #{format_number(process_count)} processes detected.</p>
        <p style="color: #8b949e; font-size: 12px;">Detailed process listing is disabled when process count exceeds 10,000 to prevent performance issues.</p>
      </div>
      """
    else
      rows =
        Process.list()
        |> Enum.map(fn pid ->
          info =
            Process.info(pid, [
              :registered_name,
              :memory,
              :reductions,
              :message_queue_len,
              :current_function
            ])

          if info, do: {pid, info}, else: nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.sort_by(fn {_pid, info} -> info[:memory] end, :desc)
        |> Enum.take(100)
        |> Enum.map(fn {pid, info} ->
          name =
            case info[:registered_name] do
              [] -> inspect(pid)
              name -> to_string(name)
            end

          func =
            case info[:current_function] do
              {m, f, a} -> "#{inspect(m)}.#{f}/#{a}"
              _ -> "-"
            end

          "<tr><td>#{html_escape(inspect(pid))}</td><td>#{html_escape(name)}</td><td>#{format_bytes(info[:memory])}</td><td>#{format_number(info[:reductions])}</td><td>#{info[:message_queue_len]}</td><td>#{html_escape(func)}</td></tr>"
        end)
        |> Enum.join("\n")

      """
      <h2>Processes (Top 100 by memory)</h2>
      <table>
        <thead>
          <tr><th>PID</th><th>Name</th><th>Memory</th><th>Reductions</th><th>MsgQ</th><th>Current Function</th></tr>
        </thead>
        <tbody>
          #{rows}
        </tbody>
      </table>
      """
    end
  end

  # ── ETS page ──

  defp render_ets do
    rows =
      :ets.all()
      |> Enum.map(fn table ->
        try do
          info = :ets.info(table)

          if info do
            name = info[:name] || inspect(table)
            size = info[:size] || 0
            mem = (info[:memory] || 0) * :erlang.system_info(:wordsize)
            type = info[:type] || :unknown
            owner = info[:owner] || :unknown

            "<tr><td>#{html_escape(inspect(name))}</td><td>#{format_number(size)}</td><td>#{format_bytes(mem)}</td><td>#{type}</td><td>#{html_escape(inspect(owner))}</td></tr>"
          else
            nil
          end
        rescue
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    <h2>ETS Tables</h2>
    <table>
      <thead>
        <tr><th>Name</th><th>Size</th><th>Memory</th><th>Type</th><th>Owner</th></tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  # ── Ports page ──

  defp render_ports do
    rows =
      Port.list()
      |> Enum.map(fn port ->
        info = Port.info(port)

        if info do
          name = Keyword.get(info, :name, "-") |> to_string()
          id = Keyword.get(info, :id, "-")
          connected = Keyword.get(info, :connected, "-")

          "<tr><td>#{html_escape(inspect(port))}</td><td>#{id}</td><td>#{html_escape(name)}</td><td>#{html_escape(inspect(connected))}</td></tr>"
        else
          nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    """
    <h2>Ports</h2>
    <table>
      <thead>
        <tr><th>Port</th><th>ID</th><th>Name</th><th>Connected</th></tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  # ── Applications page ──

  defp render_applications do
    loaded = Application.loaded_applications()
    started = Application.started_applications() |> Enum.map(fn {name, _, _} -> name end)

    rows =
      loaded
      |> Enum.sort_by(fn {name, _, _} -> name end)
      |> Enum.map(fn {name, desc, vsn} ->
        status =
          if name in started,
            do: "<span style=\"color:#238636\">started</span>",
            else: "<span style=\"color:#8b949e\">loaded</span>"

        "<tr><td>#{name}</td><td>#{html_escape(to_string(desc))}</td><td>#{vsn}</td><td>#{status}</td></tr>"
      end)
      |> Enum.join("\n")

    """
    <h2>OTP Applications</h2>
    <table>
      <thead>
        <tr><th>Name</th><th>Description</th><th>Version</th><th>Status</th></tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  # ── Memory page ──

  defp render_memory do
    mem = :erlang.memory()

    rows =
      mem
      |> Enum.map(fn {key, value} ->
        "<tr><td>#{key}</td><td>#{format_bytes(value)}</td><td>#{format_number(value)} bytes</td></tr>"
      end)
      |> Enum.join("\n")

    """
    <h2>Memory Allocation</h2>
    <table>
      <thead>
        <tr><th>Type</th><th>Size</th><th>Bytes</th></tr>
      </thead>
      <tbody>
        #{rows}
      </tbody>
    </table>
    """
  end

  # ── Helpers ──

  defp format_uptime do
    {uptime_ms, _} = :erlang.statistics(:wall_clock)
    total_seconds = div(uptime_ms, 1000)
    days = div(total_seconds, 86400)
    hours = div(rem(total_seconds, 86400), 3600)
    minutes = div(rem(total_seconds, 3600), 60)
    seconds = rem(total_seconds, 60)

    cond do
      days > 0 -> "#{days}d #{hours}h #{minutes}m"
      hours > 0 -> "#{hours}h #{minutes}m #{seconds}s"
      true -> "#{minutes}m #{seconds}s"
    end
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_073_741_824 -> "#{Float.round(bytes / 1_073_741_824, 2)} GB"
      bytes >= 1_048_576 -> "#{Float.round(bytes / 1_048_576, 2)} MB"
      bytes >= 1024 -> "#{Float.round(bytes / 1024, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_number(n) when is_integer(n) do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(n), do: to_string(n)

  defp render_bar(pct) do
    bar_class =
      cond do
        pct > 80 -> "bar danger"
        pct > 50 -> "bar warn"
        true -> "bar"
      end

    width = min(pct, 100)
    ~s(<div class="bar-container"><div class="#{bar_class}" style="width:#{width}%"></div></div>)
  end

  defp html_escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp html_escape(other), do: html_escape(to_string(other))
end
