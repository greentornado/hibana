defmodule Pastebin.PageController do
  use Hibana.Controller

  def home(conn) do
    locale = Map.get(conn.assigns, :locale, "en")
    pastes = Pastebin.Store.list_recent(10)

    rows =
      pastes
      |> Enum.map(fn p ->
        "<tr><td><a href=\"/p/#{p.id}\">#{esc(p.title)}</a></td><td><code>#{p.language}</code></td><td>#{p.view_count}</td><td>#{p.created_at}</td></tr>"
      end)
      |> Enum.join("\n")

    html(conn, """
    <!DOCTYPE html>
    <html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Pastebin — Hibana</title>
    <style>
      *{margin:0;padding:0;box-sizing:border-box}
      body{font-family:-apple-system,sans-serif;background:#0f172a;color:#e2e8f0;padding:40px}
      h1{font-size:2rem;margin-bottom:8px}
      .sub{color:#94a3b8;margin-bottom:24px}
      textarea{width:100%;height:200px;padding:12px;border-radius:8px;border:1px solid #334155;background:#1e293b;color:#e2e8f0;font-family:monospace;font-size:14px;margin-bottom:12px}
      .row{display:flex;gap:12px;margin-bottom:24px}
      input,select{padding:10px;border-radius:6px;border:1px solid #334155;background:#1e293b;color:#e2e8f0;font-size:14px}
      input{flex:1}
      button{padding:10px 24px;border-radius:6px;border:none;background:#3b82f6;color:#fff;cursor:pointer;font-size:14px}
      button:hover{background:#2563eb}
      table{width:100%;border-collapse:collapse;margin-top:12px}
      th,td{text-align:left;padding:8px 12px;border-bottom:1px solid #1e293b}
      th{color:#94a3b8}
      a{color:#60a5fa;text-decoration:none}
      code{background:#1e293b;padding:2px 6px;border-radius:4px;font-size:13px}
    </style></head><body>
    <h1>Pastebin</h1>
    <p class="sub">#{Hibana.Plugins.I18n.t(locale, "create_paste")} — Powered by Hibana</p>

    <form onsubmit="createPaste(event)">
      <div class="row"><input type="text" id="title" placeholder="Title (optional)" />
      <select id="language"><option>text</option><option>elixir</option><option>python</option><option>javascript</option><option>json</option><option>sql</option><option>html</option><option>css</option></select>
      <select id="expires"><option value="0">Never</option><option value="3600">1 hour</option><option value="86400">24 hours</option><option value="604800">7 days</option></select></div>
      <textarea id="content" placeholder="Paste your code here..."></textarea>
      <button type="submit">#{Hibana.Plugins.I18n.t(locale, "create_paste")}</button>
    </form>

    <div id="result" style="margin:16px 0;padding:12px;background:#1e293b;border-radius:8px;display:none"></div>

    <h2 style="margin-top:32px;margin-bottom:8px">#{Hibana.Plugins.I18n.t(locale, "recent")}</h2>
    <table><thead><tr><th>Title</th><th>Language</th><th>#{Hibana.Plugins.I18n.t(locale, "views")}</th><th>Created</th></tr></thead>
    <tbody>#{rows}</tbody></table>

    <script>
    async function createPaste(e){
      e.preventDefault();
      const res=await fetch('/api/pastes',{method:'POST',headers:{'Content-Type':'application/json'},
        body:JSON.stringify({title:document.getElementById('title').value||'Untitled',
          content:document.getElementById('content').value,language:document.getElementById('language').value,
          expires_in:document.getElementById('expires').value})});
      const data=await res.json();
      const el=document.getElementById('result');
      el.style.display='block';
      if(data.url){const a=document.createElement('a');a.href=data.url;a.textContent=location.origin+data.url;el.textContent='Created: ';el.appendChild(a)}
      else{el.textContent='Error'}
    }
    </script></body></html>
    """)
  end

  def view_paste(conn) do
    locale = Map.get(conn.assigns, :locale, "en")

    case Pastebin.Store.get_and_increment_views(conn.params["id"]) do
      {:ok, paste} ->
        expires_text =
          if paste.expires_at,
            do: "#{Hibana.Plugins.I18n.t(locale, "expires_in")}: #{paste.expires_at}",
            else: Hibana.Plugins.I18n.t(locale, "never")

        html(conn, """
        <!DOCTYPE html>
        <html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>#{esc(paste.title)} — Pastebin</title>
        <style>
          *{margin:0;padding:0;box-sizing:border-box}
          body{font-family:-apple-system,sans-serif;background:#0f172a;color:#e2e8f0;padding:40px}
          h1{font-size:1.5rem;margin-bottom:8px}
          .meta{color:#94a3b8;margin-bottom:16px;display:flex;gap:16px}
          .meta span{display:flex;align-items:center;gap:4px}
          pre{background:#1e293b;padding:16px;border-radius:8px;overflow-x:auto;font-size:14px;line-height:1.6}
          code{font-family:monospace}
          .badge{background:#3b82f6;color:#fff;padding:2px 8px;border-radius:4px;font-size:12px}
          a{color:#60a5fa;text-decoration:none}
          .actions{margin-top:16px;display:flex;gap:12px}
          button{padding:8px 16px;border-radius:6px;border:none;background:#334155;color:#e2e8f0;cursor:pointer}
        </style></head><body>
        <a href="/" style="margin-bottom:16px;display:inline-block">&larr; Back</a>
        <h1>#{esc(paste.title)} <span class="badge">#{paste.language}</span></h1>
        <div class="meta">
          <span>#{Hibana.Plugins.I18n.t(locale, "views")}: #{paste.view_count}</span>
          <span>#{expires_text}</span>
          <span>#{paste.created_at}</span>
        </div>
        <pre><code>#{esc(paste.content)}</code></pre>
        <div class="actions">
          <a href="/raw/#{paste.id}"><button>#{Hibana.Plugins.I18n.t(locale, "raw")}</button></a>
          <button onclick="navigator.clipboard.writeText(document.querySelector('code').textContent)">#{Hibana.Plugins.I18n.t(locale, "copy")}</button>
        </div>
        </body></html>
        """)

      :not_found ->
        conn
        |> put_status(404)
        |> html("<h1>#{Hibana.Plugins.I18n.t(locale, "not_found")}</h1>")
    end
  end

  def raw(conn) do
    case Pastebin.Store.get(conn.params["id"]) do
      {:ok, paste} -> text(conn, paste.content)
      :not_found -> conn |> put_status(404) |> text("Not found")
    end
  end

  defp esc(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp esc(other), do: to_string(other)
end
