defmodule Hibana.Plugins.Compression do
  @moduledoc """
  Response compression plugin supporting gzip and deflate.

  ## Usage

      plug Hibana.Plugins.Compression
      plug Hibana.Plugins.Compression, level: 6, min_size: 1024

  ## Options

  - `:level` - Compression level from 0 (no compression) to 9 (maximum compression), used for deflate encoding (default: `6`)
  - `:min_size` - Minimum response body size in bytes before compression is applied (default: `860`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      level: Keyword.get(opts, :level, 6),
      min_size: Keyword.get(opts, :min_size, 860)
    }
  end

  @impl true
  def call(conn, opts) do
    register_before_send(conn, fn conn ->
      if should_compress?(conn, opts) do
        compress(conn, opts)
      else
        conn
      end
    end)
  end

  defp should_compress?(conn, opts) do
    body = conn.resp_body

    has_body =
      if body do
        byte_size(IO.iodata_to_binary(body)) >= opts.min_size
      else
        false
      end

    has_body and not compressed?(conn) and accepts_encoding?(conn)
  end

  defp compress(conn, opts) do
    encoding = preferred_encoding(conn)
    body = IO.iodata_to_binary(conn.resp_body)

    case encoding do
      "gzip" ->
        compressed = :zlib.gzip(body)

        conn
        |> put_resp_header("content-encoding", "gzip")
        |> put_resp_header("vary", "Accept-Encoding")
        |> delete_resp_header("content-length")
        |> Map.put(:resp_body, compressed)

      "deflate" ->
        z = :zlib.open()
        :zlib.deflateInit(z, opts.level)
        compressed = :zlib.deflate(z, body, :finish) |> IO.iodata_to_binary()
        :zlib.deflateEnd(z)
        :zlib.close(z)

        conn
        |> put_resp_header("content-encoding", "deflate")
        |> put_resp_header("vary", "Accept-Encoding")
        |> delete_resp_header("content-length")
        |> Map.put(:resp_body, compressed)

      _ ->
        conn
    end
  end

  defp accepts_encoding?(conn) do
    case get_req_header(conn, "accept-encoding") do
      [header | _] -> String.contains?(header, "gzip") or String.contains?(header, "deflate")
      _ -> false
    end
  end

  defp preferred_encoding(conn) do
    case get_req_header(conn, "accept-encoding") do
      [header | _] ->
        cond do
          String.contains?(header, "gzip") -> "gzip"
          String.contains?(header, "deflate") -> "deflate"
          true -> nil
        end

      _ ->
        nil
    end
  end

  defp compressed?(conn) do
    case get_resp_header(conn, "content-encoding") do
      [_ | _] -> true
      _ -> false
    end
  end
end
