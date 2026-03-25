defmodule SystemMonitor.PageController do
  use Hibana.Controller

  def index(conn) do
    html_path = Path.join(:code.priv_dir(:system_monitor), "static/index.html")

    case File.read(html_path) do
      {:ok, content} ->
        html(conn, content)

      {:error, _} ->
        conn
        |> put_status(500)
        |> html("<h1>Dashboard HTML not found</h1>")
    end
  end
end
