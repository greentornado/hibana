defmodule Hibana.Plugins.DevErrorPage do
  @moduledoc """
  Rich error pages for development with stack traces, request info, and code context.

  ## Usage

      # Only in dev!
      plug Hibana.Plugins.DevErrorPage

  ## Options

  - `:enabled` - Whether the dev error page rendering is active (default: `true`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts), do: %{enabled: Keyword.get(opts, :enabled, true)}

  @impl true
  def call(conn, %{enabled: true}) do
    register_before_send(conn, fn conn ->
      if conn.status >= 500 and not conn.halted do
        render_error_page(conn)
      else
        conn
      end
    end)
  end

  def call(conn, _), do: conn

  @doc """
  Renders an exception as a rich HTML error page with stack trace and request info.

  This function is designed for development use only. It displays:

  - Exception type and message
  - Request details (method, path, query, headers)
  - Full stack trace with application vs library frame highlighting

  ## Parameters

    - `conn` - The connection struct
    - `kind` - The error kind (`:error`, `:throw`, `:exit`)
    - `reason` - The exception struct or thrown value
    - `stacktrace` - The Erlang stack trace

  ## Returns

  The connection with a 500 HTML response.

  ## Examples

      ```elixir
      try do
        raise "something went wrong"
      rescue
        e ->
          Hibana.Plugins.DevErrorPage.render_exception(conn, :error, e, __STACKTRACE__)
      end
      ```
  """
  def render_exception(conn, kind, reason, stacktrace) do
    html = build_error_html(kind, reason, stacktrace, conn)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(500, html)
    |> halt()
  end

  defp render_error_page(conn) do
    %{conn | resp_body: build_simple_error_html(conn)}
  end

  defp build_error_html(kind, reason, stacktrace, conn) do
    title = exception_title(kind, reason)
    message = Exception.message(reason) |> html_escape()
    stack_html = format_stacktrace(stacktrace)
    request_html = format_request(conn)

    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>#{title}</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace; background: #1a1a2e; color: #e0e0e0; }
        .header { background: #e74c3c; color: white; padding: 24px 32px; }
        .header h1 { font-size: 20px; font-weight: 600; }
        .header .message { margin-top: 8px; font-size: 16px; opacity: 0.9; font-family: monospace; }
        .section { padding: 24px 32px; border-bottom: 1px solid #2a2a4a; }
        .section h2 { font-size: 14px; color: #888; text-transform: uppercase; margin-bottom: 12px; }
        .stack-frame { padding: 8px 12px; border-radius: 4px; margin: 4px 0; font-family: monospace; font-size: 13px; }
        .stack-frame.app { background: #2a2a4a; color: #fff; }
        .stack-frame.lib { background: #1e1e36; color: #666; }
        .stack-file { color: #3498db; }
        .stack-func { color: #2ecc71; }
        .req-table { width: 100%; }
        .req-table td { padding: 4px 8px; font-family: monospace; font-size: 13px; }
        .req-table td:first-child { color: #888; width: 150px; }
        .req-table td:last-child { color: #fff; }
        .badge { display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 12px; font-weight: 600; }
        .badge-method { background: #3498db; color: white; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>#{title}</h1>
        <div class="message">#{message}</div>
      </div>
      <div class="section">
        <h2>Request</h2>
        #{request_html}
      </div>
      <div class="section">
        <h2>Stack Trace</h2>
        #{stack_html}
      </div>
      <div class="section" style="color: #666; font-size: 12px; padding: 12px 32px;">
        Hibana Dev Error Page -- This page is only shown in development.
      </div>
    </body>
    </html>
    """
  end

  defp build_simple_error_html(conn) do
    """
    <!DOCTYPE html>
    <html>
    <head><title>500 Error</title>
    <style>body{font-family:monospace;background:#1a1a2e;color:#e0e0e0;padding:40px;}
    h1{color:#e74c3c;}pre{background:#2a2a4a;padding:16px;border-radius:4px;overflow:auto;}</style></head>
    <body><h1>500 -- Internal Server Error</h1>
    <pre>#{html_escape(conn.method)} #{html_escape(conn.request_path)}\nStatus: #{conn.status}</pre>
    </body></html>
    """
  end

  defp exception_title(:error, %{__struct__: mod}), do: inspect(mod)
  defp exception_title(kind, _), do: to_string(kind)

  defp format_stacktrace(stacktrace) do
    stacktrace
    |> Enum.map(fn
      {mod, fun, arity, location} ->
        file = Keyword.get(location, :file, ~c"?") |> to_string()
        line = Keyword.get(location, :line, 0)
        arity_str = if is_list(arity), do: length(arity), else: arity
        is_app = not String.contains?(file, "/deps/") and not String.starts_with?(file, "(")

        class = if is_app, do: "app", else: "lib"

        """
        <div class="stack-frame #{class}">
          <span class="stack-func">#{inspect(mod)}.#{fun}/#{arity_str}</span>
          <span class="stack-file">#{file}:#{line}</span>
        </div>
        """

      _ ->
        ""
    end)
    |> Enum.join("\n")
  end

  defp format_request(conn) do
    headers =
      conn.req_headers
      |> Enum.map(fn {k, v} ->
        "<tr><td>#{html_escape(k)}</td><td>#{html_escape(v)}</td></tr>"
      end)
      |> Enum.join()

    """
    <table class="req-table">
      <tr><td>Method</td><td><span class="badge badge-method">#{conn.method}</span></td></tr>
      <tr><td>Path</td><td>#{html_escape(conn.request_path)}</td></tr>
      <tr><td>Query</td><td>#{html_escape(conn.query_string)}</td></tr>
      <tr><td>Remote IP</td><td>#{conn.remote_ip |> Tuple.to_list() |> Enum.join(".")}</td></tr>
      #{headers}
    </table>
    """
  end

  defp html_escape(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  defp html_escape(other), do: html_escape(to_string(other))
end
