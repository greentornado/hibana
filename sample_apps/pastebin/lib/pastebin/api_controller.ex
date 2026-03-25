defmodule Pastebin.ApiController do
  use Hibana.Controller

  def create(conn) do
    case Pastebin.Store.create(conn.body_params) do
      {:ok, paste} ->
        conn |> Plug.Conn.put_status(201) |> json(%{paste: paste, url: "/p/#{paste.id}"})
    end
  end

  def list_recent(conn) do
    pastes = Pastebin.Store.list_recent()
    json(conn, %{pastes: pastes, total: length(pastes)})
  end

  def show(conn) do
    case Pastebin.Store.get(conn.params["id"]) do
      {:ok, paste} -> json(conn, %{paste: paste})
      :not_found -> conn |> Plug.Conn.put_status(404) |> json(%{error: "Paste not found"})
    end
  end

  def delete_paste(conn) do
    Pastebin.Store.delete(conn.params["id"])
    json(conn, %{deleted: true})
  end
end
