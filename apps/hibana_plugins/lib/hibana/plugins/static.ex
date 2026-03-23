defmodule Hibana.Plugins.Static do
  @moduledoc """
  Static file serving plugin for serving files from disk.

  ## Features

  - Serves files from configured directory
  - Automatic content-type detection
  - Cache control headers in production
  - Gzip support (optional)
  - Security: does not serve files outside root

  ## Usage

      # Serve from priv/static at root
      plug Hibana.Plugins.Static, at: "/", from: "priv/static"

      # Serve at /public prefix
      plug Hibana.Plugins.Static, at: "/public", from: "priv/static"

  ## Options

  - `:at` - URL prefix to serve (default: `"/"`)
  - `:from` - Directory to serve files from (default: `"priv/static"`)
  - `:gzip` - Enable gzip support (default: `false`)
  - `:cache_headers` - Add cache headers (default: `true`)

  ## Caching

  In production (`MIX_ENV=prod`), adds cache headers:

      Cache-Control: public, max-age=3600

  In development, no caching.

  ## Supported Content-Types

  - HTML, CSS, JS, JSON
  - Images (PNG, JPG, GIF, SVG, ICO)
  - Fonts (WOFF, WOFF2, TTF, EOT)
  - PDF, TXT, and binary files
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      at: Keyword.get(opts, :at, "/"),
      from: Keyword.get(opts, :from, "priv/static"),
      gzip: Keyword.get(opts, :gzip, false),
      cache_headers: Keyword.get(opts, :cache_headers, true)
    }
  end

  @impl true
  def call(conn, %{at: at, from: from}) do
    case static_path(conn, at, from) do
      nil ->
        conn

      path ->
        case File.exists?(path) do
          true ->
            content_type = content_type_for_path(path)
            cache_max_age = if Application.get_env(:hibana, :env) == :prod, do: 3600, else: 0

            conn
            |> put_resp_content_type(content_type)
            |> maybe_cache(cache_max_age)
            |> Plug.Conn.send_file(200, path)
            |> halt()

          false ->
            conn
        end
    end
  end

  defp static_path(conn, at, from) do
    path = conn.path_info |> Enum.join("/")
    at_path = String.trim(at, "/")

    if String.starts_with?(path, at_path) do
      relative_path = String.replace(path, at_path, "", global: false) |> String.trim_leading("/")

      # Reject path traversal
      if String.contains?(relative_path, "..") do
        nil
      else
        full_path = Path.join(from, relative_path) |> Path.expand()
        root = Path.expand(from)

        if String.starts_with?(full_path, root) do
          full_path
        else
          nil
        end
      end
    else
      nil
    end
  end

  defp content_type_for_path(path) do
    case Path.extname(path) do
      ".html" -> "text/html; charset=utf-8"
      ".css" -> "text/css; charset=utf-8"
      ".js" -> "application/javascript; charset=utf-8"
      ".json" -> "application/json; charset=utf-8"
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".jpeg" -> "image/jpeg"
      ".gif" -> "image/gif"
      ".svg" -> "image/svg+xml"
      ".ico" -> "image/x-icon"
      ".woff" -> "font/woff"
      ".woff2" -> "font/woff2"
      ".ttf" -> "font/ttf"
      ".eot" -> "application/vnd.ms-fontobject"
      ".pdf" -> "application/pdf"
      ".txt" -> "text/plain; charset=utf-8"
      _ -> "application/octet-stream"
    end
  end

  defp maybe_cache(conn, 0), do: conn

  defp maybe_cache(conn, max_age) do
    put_resp_header(conn, "cache-control", "public, max-age=#{max_age}")
  end
end
