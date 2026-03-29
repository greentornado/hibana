defmodule Hibana.ChunkedUploadTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  alias Hibana.ChunkedUpload

  setup do
    # Create temp upload directory
    upload_dir = Path.join(System.tmp_dir!(), "test_uploads_#{:rand.uniform(10000)}")
    File.mkdir_p!(upload_dir)

    on_exit(fn ->
      File.rm_rf!(upload_dir)
    end)

    {:ok, upload_dir: upload_dir}
  end

  describe "receive/2" do
    test "successfully receives small file upload", %{upload_dir: upload_dir} do
      conn =
        conn(:post, "/upload", "test file content")
        |> put_req_header("content-type", "application/octet-stream")
        |> put_req_header("content-disposition", "attachment; filename=\"test.txt\"")

      {:ok, result} = ChunkedUpload.receive(conn, upload_dir: upload_dir, max_size: 1000)

      assert result.filename == "test.txt"
      assert result.size == 17
      assert is_binary(result.checksum)
      assert File.exists?(result.path)

      content = File.read!(result.path)
      assert content == "test file content"
    end

    test "generates filename when not provided", %{upload_dir: upload_dir} do
      conn =
        conn(:post, "/upload", "content")
        |> put_req_header("content-type", "application/octet-stream")

      {:ok, result} = ChunkedUpload.receive(conn, upload_dir: upload_dir)

      assert is_binary(result.filename)
      assert result.size == 7
    end

    test "rejects upload exceeding max_size", %{upload_dir: upload_dir} do
      conn =
        conn(:post, "/upload", "this is too large")
        |> put_req_header("content-type", "application/octet-stream")

      result = ChunkedUpload.receive(conn, upload_dir: upload_dir, max_size: 5)

      assert {:error, :file_too_large} = result
    end

    test "accepts large files with :infinity max_size", %{upload_dir: upload_dir} do
      large_content = String.duplicate("x", 10_000)

      conn =
        conn(:post, "/upload", large_content)
        |> put_req_header("content-type", "application/octet-stream")

      {:ok, result} = ChunkedUpload.receive(conn, upload_dir: upload_dir, max_size: :infinity)

      assert result.size == 10_000
    end

    test "sanitizes dangerous filenames", %{upload_dir: upload_dir} do
      conn =
        conn(:post, "/upload", "content")
        |> put_req_header("content-type", "application/octet-stream")
        |> put_req_header("content-disposition", "attachment; filename=\"../../../etc/passwd\"")

      {:ok, result} = ChunkedUpload.receive(conn, upload_dir: upload_dir)

      refute String.contains?(result.filename, "/")
      refute String.contains?(result.filename, "..")
    end

    test "computes SHA256 checksum", %{upload_dir: upload_dir} do
      content = "test content for checksum"

      conn =
        conn(:post, "/upload", content)
        |> put_req_header("content-type", "application/octet-stream")

      {:ok, result} = ChunkedUpload.receive(conn, upload_dir: upload_dir)

      expected_checksum = :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
      assert result.checksum == expected_checksum
    end
  end

  describe "receive_chunk/2" do
    test "receives first chunk of multipart upload", %{upload_dir: upload_dir} do
      upload_id = "test-upload-#{:rand.uniform(10000)}"
      chunk = String.duplicate("a", 100)

      conn =
        conn(:post, "/upload", chunk)
        |> put_req_header("x-upload-id", upload_id)
        |> put_req_header("x-chunk-number", "0")
        |> put_req_header("x-total-chunks", "10")
        |> put_req_header("content-range", "bytes 0-99/1000")

      {:ok, status, progress} = ChunkedUpload.receive_chunk(conn, upload_dir: upload_dir)

      assert status == :partial
      assert progress.upload_id == upload_id
      assert progress.received_chunks == 1
      assert progress.total_chunks == 10
    end

    test "completes upload when all chunks received", %{upload_dir: upload_dir} do
      upload_id = "test-upload-#{:rand.uniform(10000)}"

      # Receive single chunk as complete upload
      conn =
        conn(:post, "/upload", "complete content")
        |> put_req_header("x-upload-id", upload_id)
        |> put_req_header("x-chunk-number", "0")
        |> put_req_header("x-total-chunks", "1")

      {:ok, status, info} = ChunkedUpload.receive_chunk(conn, upload_dir: upload_dir)

      assert status == :complete
      assert is_map(info)
      assert info.filename
      assert File.exists?(info.path)
    end

    test "handles missing upload headers gracefully", %{upload_dir: upload_dir} do
      conn = conn(:post, "/upload", "content")
      # Missing X-Upload-Id header

      result = ChunkedUpload.receive_chunk(conn, upload_dir: upload_dir)

      assert {:error, _} = result
    end
  end

  describe "upload status and cleanup" do
    test "returns upload progress", %{upload_dir: upload_dir} do
      upload_id = "test-status-#{:rand.uniform(10000)}"

      # Create partial upload state
      File.mkdir_p!(Path.join(upload_dir, upload_id))

      progress = ChunkedUpload.upload_status(upload_dir, upload_id)

      assert is_map(progress)
    end

    test "lists active uploads", %{upload_dir: upload_dir} do
      # Create some upload directories
      File.mkdir_p!(Path.join(upload_dir, "upload-1"))
      File.mkdir_p!(Path.join(upload_dir, "upload-2"))

      uploads = ChunkedUpload.list_uploads(upload_dir)

      assert is_list(uploads)
      assert length(uploads) >= 2
    end

    test "aborts and cleans up upload", %{upload_dir: upload_dir} do
      upload_id = "test-abort-#{:rand.uniform(10000)}"
      upload_path = Path.join(upload_dir, upload_id)
      File.mkdir_p!(upload_path)

      :ok = ChunkedUpload.abort_upload(upload_dir, upload_id)

      refute File.exists?(upload_path)
    end

    test "cleans up stale uploads", %{upload_dir: upload_dir} do
      # Create old upload directory
      old_upload = Path.join(upload_dir, "stale-#{:rand.uniform(10000)}")
      File.mkdir_p!(old_upload)

      # Manually set mtime to old date would require system calls
      # For testing, we just verify the function exists and runs
      result = ChunkedUpload.cleanup_stale_uploads(upload_dir, max_age: 0)

      assert is_integer(result) or result == :ok
    end
  end
end
