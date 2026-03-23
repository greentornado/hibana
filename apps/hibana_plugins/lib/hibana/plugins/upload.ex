defmodule Hibana.Plugins.Upload do
  @moduledoc """
  File upload handling plugin.

  ## Features

  - Configurable maximum file size
  - MIME type validation
  - Custom upload directory
  - Ready-to-use upload endpoint

  ## Usage

      plug Hibana.Plugins.Upload,
        max_file_size: 10_000_000,
        allowed_types: ["image/jpeg", "image/png", "application/pdf"],
        upload_dir: "priv/uploads"

  ## Options

  - `:max_file_size` - Maximum file size in bytes (default: `5_000_000` = 5MB)
  - `:allowed_types` - List of allowed MIME types (default: `[]` = all)
  - `:upload_dir` - Directory to save uploads (default: `"priv/uploads"`)

  ## Upload Endpoint

  POST /upload

  Returns JSON confirmation that endpoint is ready.
  Extend this plugin for full multipart file handling.

  ## Validation

  The plugin validates:

  - File size against `:max_file_size`
  - MIME type against `:allowed_types` (if specified)

  ## File Storage

  Uploaded files are saved to `:upload_dir` with generated filenames:

      priv/uploads/uuid-filename.ext
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      max_file_size: Keyword.get(opts, :max_file_size, 5_000_000),
      allowed_types: Keyword.get(opts, :allowed_types, []),
      upload_dir: Keyword.get(opts, :upload_dir, "priv/uploads")
    }
  end

  @impl true
  def call(conn, %{
        max_file_size: max_file_size,
        allowed_types: allowed_types,
        upload_dir: upload_dir
      }) do
    if conn.request_path == "/upload" and conn.method == "POST" do
      case conn.body_params do
        %{"file" => %Plug.Upload{filename: filename, path: tmp_path, content_type: content_type}} ->
          cond do
            max_file_size > 0 && File.stat!(tmp_path).size > max_file_size ->
              conn
              |> put_resp_content_type("application/json")
              |> send_resp(
                413,
                Jason.encode!(%{error: "File too large", max_size: max_file_size})
              )
              |> halt()

            allowed_types != [] && content_type not in allowed_types ->
              conn
              |> put_resp_content_type("application/json")
              |> send_resp(
                415,
                Jason.encode!(%{error: "File type not allowed", allowed: allowed_types})
              )
              |> halt()

            true ->
              File.mkdir_p!(upload_dir)
              safe_filename = Path.basename(filename)

              dest_filename =
                "#{:crypto.strong_rand_bytes(8) |> Base.encode16()}-#{safe_filename}"

              dest_path = Path.join(upload_dir, dest_filename)
              File.cp!(tmp_path, dest_path)

              conn
              |> put_resp_content_type("application/json")
              |> send_resp(
                200,
                Jason.encode!(%{
                  message: "File uploaded successfully",
                  filename: dest_filename,
                  size: File.stat!(dest_path).size,
                  content_type: content_type
                })
              )
              |> halt()
          end

        _ ->
          conn
          |> put_resp_content_type("application/json")
          |> send_resp(
            400,
            Jason.encode!(%{error: "No file provided. Send file as 'file' field."})
          )
          |> halt()
      end
    else
      conn
    end
  end
end
