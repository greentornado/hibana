defmodule QuizGame.PageController do
  use Hibana.Controller

  def index(conn) do
    file_path = Path.join(:code.priv_dir(:quiz_game), "static/index.html")

    case File.read(file_path) do
      {:ok, content} -> html(conn, content)
      {:error, _} -> put_status(conn, 500) |> text("Could not load index.html")
    end
  end

  def static(conn) do
    file = conn.params["file"]
    priv_dir = :code.priv_dir(:quiz_game)
    file_path = Path.join([priv_dir, "static", file])

    # Prevent directory traversal
    if String.contains?(file, "..") do
      put_status(conn, 403) |> text("Forbidden")
    else
      case File.read(file_path) do
        {:ok, content} ->
          content_type = mime_for(file)

          conn
          |> put_resp_content_type(content_type)
          |> send_resp(200, content)

        {:error, _} ->
          put_status(conn, 404) |> text("Not found")
      end
    end
  end

  defp mime_for(file) do
    case Path.extname(file) do
      ".html" -> "text/html"
      ".css" -> "text/css"
      ".js" -> "application/javascript"
      ".json" -> "application/json"
      ".png" -> "image/png"
      ".svg" -> "image/svg+xml"
      _ -> "application/octet-stream"
    end
  end
end
