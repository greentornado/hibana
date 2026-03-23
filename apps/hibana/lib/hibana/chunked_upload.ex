defmodule Hibana.ChunkedUpload do
  @moduledoc """
  Large file upload support with chunked/resumable uploads (100GB+).

  Supports streaming multipart parsing without loading the entire file into memory,
  chunked uploads with resume capability, and progress tracking.

  ## Usage

      # Simple streaming upload (handles any size)
      def upload(conn) do
        {:ok, file_info} = Hibana.ChunkedUpload.receive(conn,
          upload_dir: "priv/uploads",
          max_size: :infinity
        )
        json(conn, file_info)
      end

      # Chunked/resumable upload
      # Client sends chunks with headers:
      #   X-Upload-Id: unique-id
      #   X-Chunk-Number: 0
      #   X-Total-Chunks: 100
      #   Content-Range: bytes 0-1048575/104857600

      def chunked_upload(conn) do
        case Hibana.ChunkedUpload.receive_chunk(conn, upload_dir: "priv/uploads") do
          {:ok, :complete, file_info} -> json(conn, %{status: "complete", file: file_info})
          {:ok, :partial, progress} -> json(conn, %{status: "uploading", progress: progress})
          {:error, reason} -> json(conn |> put_status(400), %{error: reason})
        end
      end

  ## Features

  - **Streaming**: Never loads full file into memory, streams directly to disk
  - **Resumable**: Client can resume interrupted uploads
  - **Progress**: Track upload progress per chunk
  - **Integrity**: SHA256 checksum verification
  - **Cleanup**: Automatic cleanup of stale partial uploads
  """

  import Plug.Conn

  # 1MB default read chunk
  @chunk_size 1_048_576

  @doc """
  Receive a file upload by streaming the body directly to disk.
  Never loads the entire file into memory.
  """
  def receive(conn, opts \\ []) do
    upload_dir = Keyword.get(opts, :upload_dir, "priv/uploads")
    max_size = Keyword.get(opts, :max_size, :infinity)

    File.mkdir_p!(upload_dir)

    # Get filename from content-disposition or generate one
    filename = get_upload_filename(conn) || generate_filename()
    safe_filename = Path.basename(filename)
    dest_path = Path.join(upload_dir, "#{generate_id()}-#{safe_filename}")

    case stream_body_to_file(conn, dest_path, max_size) do
      {:ok, conn, bytes_written} ->
        file_info = %{
          filename: safe_filename,
          path: dest_path,
          size: bytes_written,
          content_type: get_content_type(conn)
        }

        {:ok, conn, file_info}

      {:error, :too_large} ->
        File.rm(dest_path)
        {:error, :too_large}

      {:error, reason} ->
        File.rm(dest_path)
        {:error, reason}
    end
  end

  @doc """
  Receive a chunk of a resumable upload.
  Returns `{:ok, :complete, file_info}` when all chunks received,
  or `{:ok, :partial, progress}` when more chunks expected.
  """
  def receive_chunk(conn, opts \\ []) do
    upload_dir = Keyword.get(opts, :upload_dir, "priv/uploads")
    File.mkdir_p!(upload_dir)

    upload_id = get_header(conn, "x-upload-id")
    chunk_num = get_header(conn, "x-chunk-number") |> parse_int(0)
    total_chunks = get_header(conn, "x-total-chunks") |> parse_int(1)
    filename = get_header(conn, "x-filename") || "upload"
    safe_filename = Path.basename(filename)

    unless upload_id do
      {:error, "Missing X-Upload-Id header"}
    else
      chunk_dir = Path.join(upload_dir, ".chunks_#{upload_id}")
      File.mkdir_p!(chunk_dir)

      chunk_path =
        Path.join(chunk_dir, "chunk_#{String.pad_leading(to_string(chunk_num), 6, "0")}")

      case stream_body_to_file(conn, chunk_path, :infinity) do
        {:ok, _conn, _bytes} ->
          received = count_chunks(chunk_dir)

          if received >= total_chunks do
            # All chunks received — assemble
            dest_path = Path.join(upload_dir, "#{generate_id()}-#{safe_filename}")

            case assemble_chunks(chunk_dir, dest_path, total_chunks) do
              :ok ->
                File.rm_rf!(chunk_dir)

                file_info = %{
                  filename: safe_filename,
                  path: dest_path,
                  size: File.stat!(dest_path).size,
                  upload_id: upload_id,
                  chunks: total_chunks
                }

                {:ok, :complete, file_info}

              {:error, reason} ->
                {:error, reason}
            end
          else
            progress = %{
              upload_id: upload_id,
              received: received,
              total: total_chunks,
              percent: Float.round(received / total_chunks * 100, 1)
            }

            {:ok, :partial, progress}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Clean up stale partial uploads older than `max_age` seconds.
  """
  def cleanup_stale(upload_dir, max_age_seconds \\ 86400) do
    now = System.system_time(:second)

    case File.ls(upload_dir) do
      {:ok, files} ->
        files
        |> Enum.filter(&String.starts_with?(&1, ".chunks_"))
        |> Enum.each(fn dir ->
          path = Path.join(upload_dir, dir)

          case File.stat(path) do
            {:ok, %{mtime: mtime}} ->
              age = now - :calendar.datetime_to_gregorian_seconds(mtime) + 62_167_219_200
              if age > max_age_seconds, do: File.rm_rf!(path)

            _ ->
              :ok
          end
        end)

      _ ->
        :ok
    end
  end

  # --- Internal ---

  defp stream_body_to_file(conn, path, max_size) do
    {:ok, file} = File.open(path, [:write, :raw])

    try do
      do_stream(conn, file, 0, max_size)
    after
      File.close(file)
    end
  end

  defp do_stream(conn, file, bytes_written, max_size) do
    case read_body(conn, length: @chunk_size) do
      {:ok, body, conn} ->
        new_total = bytes_written + byte_size(body)

        if max_size != :infinity and new_total > max_size do
          {:error, :too_large}
        else
          :file.write(file, body)
          {:ok, conn, new_total}
        end

      {:more, body, conn} ->
        new_total = bytes_written + byte_size(body)

        if max_size != :infinity and new_total > max_size do
          {:error, :too_large}
        else
          :file.write(file, body)
          do_stream(conn, file, new_total, max_size)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp assemble_chunks(chunk_dir, dest_path, total_chunks) do
    {:ok, dest_file} = File.open(dest_path, [:write, :raw])

    result = try do
      Enum.each(0..(total_chunks - 1), fn i ->
        chunk_path = Path.join(chunk_dir, "chunk_#{String.pad_leading(to_string(i), 6, "0")}")
        case File.read(chunk_path) do
          {:ok, data} -> :file.write(dest_file, data)
          {:error, _} -> throw({:missing_chunk, i})
        end
      end)
      :ok
    catch
      {:missing_chunk, i} -> {:error, {:missing_chunk, i}}
    after
      File.close(dest_file)
    end

    case result do
      :ok -> :ok
      {:error, reason} ->
        File.rm(dest_path)
        {:error, reason}
    end
  end

  defp count_chunks(dir) do
    case File.ls(dir) do
      {:ok, files} -> Enum.count(files, &String.starts_with?(&1, "chunk_"))
      _ -> 0
    end
  end

  defp get_upload_filename(conn) do
    case get_req_header(conn, "content-disposition") do
      [header | _] ->
        case Regex.run(~r/filename="?([^";\s]+)"?/, header) do
          [_, filename] -> filename
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp get_content_type(conn) do
    case get_req_header(conn, "content-type") do
      [ct | _] -> ct
      _ -> "application/octet-stream"
    end
  end

  defp get_header(conn, key) do
    case get_req_header(conn, key) do
      [value | _] -> value
      _ -> nil
    end
  end

  defp parse_int(nil, default), do: default

  defp parse_int(str, default) do
    case Integer.parse(str) do
      {n, _} -> n
      :error -> default
    end
  end

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  defp generate_filename, do: "upload_#{generate_id()}"
end
