defmodule Hibana.FileStreamer do
  @moduledoc """
  Zero-copy file streaming using sendfile(2) syscall for maximum performance.

  Uses the kernel's sendfile syscall to transfer files directly from disk to socket
  without copying through userspace, achieving maximum throughput.

  ## Usage

      # Stream a file with zero-copy (fastest)
      Hibana.FileStreamer.send_file(conn, "/path/to/file.mp4")

      # Stream with range support (for video/audio seeking)
      Hibana.FileStreamer.send_file(conn, "/path/to/video.mp4", range: true)

      # Stream with custom content type
      Hibana.FileStreamer.send_file(conn, "/path/to/data.bin",
        content_type: "application/octet-stream",
        filename: "download.bin"
      )

      # Chunked streaming from an Elixir Stream
      Hibana.FileStreamer.stream_chunks(conn, File.stream!("/path/to/large.csv", [], 64_000))

  ## Features

  - Zero-copy via `Plug.Conn.send_file/5` (uses sendfile(2) under the hood)
  - HTTP Range request support for resumable downloads and seeking
  - Automatic MIME type detection
  - ETag and Last-Modified headers for caching
  - Chunked transfer encoding for dynamic streams
  """

  import Plug.Conn

  @doc """
  Send a file using zero-copy sendfile(2).
  Supports range requests for resumable downloads and media seeking.
  """
  def send_file(conn, path, opts \\ []) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size, mtime: mtime}} ->
        content_type = Keyword.get(opts, :content_type, MIME.from_path(path))
        filename = Keyword.get(opts, :filename)
        range_support = Keyword.get(opts, :range, false)
        etag = generate_etag(path, size, mtime)

        conn =
          conn
          |> put_resp_header("accept-ranges", if(range_support, do: "bytes", else: "none"))
          |> put_resp_header("etag", etag)
          |> put_resp_header("last-modified", format_http_date(mtime))
          |> put_resp_content_type(content_type)
          |> maybe_add_disposition(filename)

        # Check If-None-Match (ETag caching)
        if etag_match?(conn, etag) do
          send_resp(conn, 304, "")
        else
          if range_support do
            handle_range_request(conn, path, size)
          else
            # Zero-copy sendfile
            conn
            |> put_resp_header("content-length", to_string(size))
            |> Plug.Conn.send_file(200, path)
          end
        end

      {:error, reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(404, "File not found: #{reason}")
    end
  end

  @doc """
  Stream chunks from an enumerable (e.g., File.stream!).
  Uses chunked transfer encoding.
  """
  def stream_chunks(conn, enumerable, opts \\ []) do
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")
    filename = Keyword.get(opts, :filename)

    conn =
      conn
      |> put_resp_content_type(content_type)
      |> maybe_add_disposition(filename)
      |> send_chunked(200)

    Enum.reduce_while(enumerable, conn, fn data, conn ->
      case chunk(conn, data) do
        {:ok, conn} -> {:cont, conn}
        {:error, _reason} -> {:halt, conn}
      end
    end)
  end

  # --- Range request handling ---

  defp handle_range_request(conn, path, total_size) do
    case get_req_header(conn, "range") do
      ["bytes=" <> range_spec | _] ->
        case parse_range(range_spec, total_size) do
          {:ok, start_pos, end_pos} ->
            length = end_pos - start_pos + 1

            conn
            |> put_resp_header("content-range", "bytes #{start_pos}-#{end_pos}/#{total_size}")
            |> put_resp_header("content-length", to_string(length))
            |> Plug.Conn.send_file(206, path, start_pos, length)

          :invalid ->
            conn
            |> put_resp_header("content-range", "bytes */#{total_size}")
            |> send_resp(416, "Range Not Satisfiable")
        end

      _ ->
        # No range header — send full file
        conn
        |> put_resp_header("content-length", to_string(total_size))
        |> Plug.Conn.send_file(200, path)
    end
  end

  defp parse_range(spec, total_size) do
    case String.split(spec, "-", parts: 2) do
      [start_str, ""] ->
        start_pos = String.to_integer(start_str)
        if start_pos < total_size, do: {:ok, start_pos, total_size - 1}, else: :invalid

      ["", end_str] ->
        suffix = String.to_integer(end_str)
        start_pos = max(total_size - suffix, 0)
        {:ok, start_pos, total_size - 1}

      [start_str, end_str] ->
        start_pos = String.to_integer(start_str)
        end_pos = min(String.to_integer(end_str), total_size - 1)
        if start_pos <= end_pos, do: {:ok, start_pos, end_pos}, else: :invalid

      _ ->
        :invalid
    end
  rescue
    _ -> :invalid
  end

  # --- Helpers ---

  defp generate_etag(path, size, mtime) do
    hash = :erlang.phash2({path, size, mtime})
    "\"#{Integer.to_string(hash, 16)}\""
  end

  defp etag_match?(conn, etag) do
    case get_req_header(conn, "if-none-match") do
      [^etag | _] -> true
      _ -> false
    end
  end

  defp format_http_date({{y, m, d}, {h, min, s}}) do
    weekdays = ~w(Mon Tue Wed Thu Fri Sat Sun)
    months = ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

    # Get day of week (1=Monday in Elixir)
    dow = :calendar.day_of_the_week({y, m, d}) - 1
    weekday = Enum.at(weekdays, dow, "Mon")
    month = Enum.at(months, m - 1, "Jan")

    "#{weekday}, #{String.pad_leading(to_string(d), 2, "0")} #{month} #{y} #{String.pad_leading(to_string(h), 2, "0")}:#{String.pad_leading(to_string(min), 2, "0")}:#{String.pad_leading(to_string(s), 2, "0")} GMT"
  end

  defp format_http_date(_), do: ""

  defp maybe_add_disposition(conn, nil), do: conn

  defp maybe_add_disposition(conn, filename) do
    put_resp_header(conn, "content-disposition", "attachment; filename=\"#{filename}\"")
  end
end
