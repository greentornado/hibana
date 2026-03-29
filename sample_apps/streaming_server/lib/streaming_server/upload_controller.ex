defmodule StreamingServer.UploadController do
  @moduledoc """
  Controller demonstrating ChunkedUpload for large file uploads (100GB+ support).

  Features:
  - Streaming upload without loading into memory
  - Chunked transfer encoding support
  - Progress tracking
  - Automatic cleanup
  """
  use Hibana.Controller

  @upload_dir Path.join(File.cwd!(), "priv/uploads")

  # Ensure upload directory exists
  File.mkdir_p!(@upload_dir)

  @doc """
  Standard file upload (uses Plug.Upload for small files).
  """
  def upload(conn) do
    case conn.body_params do
      %{"file" => %{filename: filename, path: temp_path}} ->
        dest_path = Path.join(@upload_dir, filename)

        case File.cp(temp_path, dest_path) do
          :ok ->
            {:ok, stat} = File.stat(dest_path)

            json(conn, %{
              status: "uploaded",
              filename: filename,
              size: stat.size,
              type: "standard"
            })

          {:error, reason} ->
            conn
            |> put_status(500)
            |> json(%{error: "Upload failed: #{inspect(reason)}"})
        end

      _ ->
        conn
        |> put_status(400)
        |> json(%{error: "No file uploaded"})
    end
  end

  @doc """
  Large file upload using ChunkedUpload (supports 100GB+ files).
  """
  def chunked_upload(conn) do
    upload_id = generate_upload_id()
    dest_dir = Path.join(@upload_dir, upload_id)
    File.mkdir_p!(dest_dir)

    # Use ChunkedUpload for streaming large files
    opts = [
      dest: dest_dir,
      # No size limit
      max_size: :infinity,
      # 8MB chunks
      chunk_size: 8_388_608,
      on_chunk: fn chunk_info ->
        # Broadcast progress via PubSub or logging
        IO.puts("Chunk received: #{inspect(chunk_info)}")
      end
    ]

    case Hibana.ChunkedUpload.receive(conn, opts) do
      {:ok, conn, file_info} ->
        json(conn, %{
          status: "uploaded",
          upload_id: upload_id,
          file_info: file_info,
          type: "chunked",
          message: "Large file uploaded successfully via streaming"
        })

      {:error, reason} ->
        conn
        |> put_status(400)
        |> json(%{error: "Chunked upload failed: #{inspect(reason)}"})
    end
  end

  @doc """
  List all uploaded files.
  """
  def list_uploads(conn) do
    files =
      case File.ls(@upload_dir) do
        {:ok, entries} ->
          entries
          |> Enum.map(fn entry ->
            path = Path.join(@upload_dir, entry)

            case File.stat(path) do
              {:ok, stat} ->
                %{name: entry, size: stat.size, type: (File.dir?(path) && "directory") || "file"}

              _ ->
                %{name: entry, size: 0, type: "unknown"}
            end
          end)

        _ ->
          []
      end

    json(conn, %{uploads: files, directory: @upload_dir})
  end

  defp generate_upload_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
