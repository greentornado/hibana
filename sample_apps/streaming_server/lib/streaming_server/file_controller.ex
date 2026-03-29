defmodule StreamingServer.FileController do
  @moduledoc """
  Controller demonstrating FileStreamer for zero-copy file serving.

  Features:
  - Zero-copy sendfile(2) for efficient file transfers
  - HTTP Range requests for resumable downloads and video seeking
  - ETag caching support
  - Proper content-type detection
  """
  use Hibana.Controller

  @upload_dir Path.join(File.cwd!(), "priv/uploads")

  @doc """
  Simple file download using FileStreamer.
  """
  def download(conn) do
    filename = conn.params["filename"]

    if File.exists?(Path.join(@upload_dir, filename)) do
      Hibana.FileStreamer.send_file(conn, filename,
        filename: filename,
        range: false,
        base_dir: @upload_dir
      )
    else
      conn
      |> put_status(404)
      |> json(%{error: "File not found", filename: filename})
    end
  end

  @doc """
  Stream file with Range request support (for video seeking, resumable downloads).
  """
  def stream(conn) do
    filename = conn.params["filename"]

    if File.exists?(Path.join(@upload_dir, filename)) do
      Hibana.FileStreamer.send_file(conn, filename,
        filename: filename,
        # Enable Range request support
        range: true,
        base_dir: @upload_dir
      )
    else
      conn
      |> put_status(404)
      |> json(%{error: "File not found", filename: filename})
    end
  end

  @doc """
  Download with forced content disposition (forces browser download dialog).
  """
  def download_with_range(conn) do
    filename = conn.params["filename"]

    if File.exists?(Path.join(@upload_dir, filename)) do
      Hibana.FileStreamer.send_file(conn, filename,
        filename: filename,
        range: true,
        content_type: MIME.from_path(Path.join(@upload_dir, filename)),
        base_dir: @upload_dir
      )
    else
      conn
      |> put_status(404)
      |> json(%{error: "File not found", filename: filename})
    end
  end
end
