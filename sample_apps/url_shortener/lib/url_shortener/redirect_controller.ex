defmodule UrlShortener.RedirectController do
  use Hibana.Controller

  def home(conn) do
    urls = UrlShortener.Store.list() |> Enum.take(10)

    rows =
      urls
      |> Enum.map(fn u ->
        code_escaped = HtmlEscape.escape(u.code)
        url_escaped = HtmlEscape.escape(u.url)

        """
        <tr>
          <td><a href="/#{code_escaped}">/#{code_escaped}</a></td>
          <td style="max-width:300px;overflow:hidden;text-overflow:ellipsis">#{url_escaped}</td>
          <td>#{u.click_count}</td>
          <td><a href="/api/stats/#{code_escaped}">Stats</a></td>
        </tr>
        """
      end)
      |> Enum.join("\n")

    html(conn, """
    <!DOCTYPE html>
    <html>
    <head>
      <title>URL Shortener — Hibana</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, sans-serif; background: #0f172a; color: #e2e8f0; padding: 40px; }
        h1 { font-size: 2rem; margin-bottom: 8px; }
        .subtitle { color: #94a3b8; margin-bottom: 32px; }
        form { display: flex; gap: 12px; margin-bottom: 32px; }
        input[type=url] { flex: 1; padding: 12px 16px; border-radius: 8px; border: 1px solid #334155; background: #1e293b; color: #e2e8f0; font-size: 16px; }
        button { padding: 12px 24px; border-radius: 8px; border: none; background: #3b82f6; color: white; font-size: 16px; cursor: pointer; }
        button:hover { background: #2563eb; }
        #result { margin-bottom: 32px; padding: 16px; background: #1e293b; border-radius: 8px; display: none; }
        #result a { color: #60a5fa; }
        table { width: 100%; border-collapse: collapse; }
        th, td { text-align: left; padding: 10px 12px; border-bottom: 1px solid #1e293b; }
        th { color: #94a3b8; font-weight: 500; }
        a { color: #60a5fa; text-decoration: none; }
      </style>
    </head>
    <body>
      <h1>URL Shortener</h1>
      <p class="subtitle">Powered by Hibana Framework</p>

      <form onsubmit="shorten(event)">
        <input type="url" id="url" placeholder="https://example.com/very/long/url" required />
        <button type="submit">Shorten</button>
      </form>

      <div id="result"></div>

      <h2 style="margin-bottom:12px">Recent URLs</h2>
      <table>
        <thead><tr><th>Short</th><th>Original</th><th>Clicks</th><th>Analytics</th></tr></thead>
        <tbody>#{rows}</tbody>
      </table>

      <script>
        async function shorten(e) {
          e.preventDefault();
          const url = document.getElementById('url').value;
          const res = await fetch('/api/shorten', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({url})
          });
          const data = await res.json();
          const el = document.getElementById('result');
          el.style.display = 'block';
          if (data.short_url) {
            el.textContent = '';
            const text = document.createTextNode('Shortened: ');
            const link = document.createElement('a');
            link.href = data.short_url;
            link.textContent = data.short_url;
            el.appendChild(text);
            el.appendChild(link);
          } else {
            el.textContent = 'Error: ' + (data.error || 'Unknown');
          }
        }
      </script>
    </body>
    </html>
    """)
  end

  def redirect(conn) do
    code = conn.params["code"]

    case UrlShortener.Store.get(code) do
      {:ok, %{url: url}} ->
        referrer = Plug.Conn.get_req_header(conn, "referer") |> List.first()
        user_agent = Plug.Conn.get_req_header(conn, "user-agent") |> List.first()
        UrlShortener.Store.record_click(code, referrer, user_agent)
        redirect(conn, to: url)

      :not_found ->
        conn |> Plug.Conn.put_status(404) |> json(%{error: "Short URL not found"})
    end
  end
end

defmodule HtmlEscape do
  def escape(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end

  def escape(other), do: to_string(other)
end
