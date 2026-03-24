# `Hibana.ChunkedUpload`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/chunked_upload.ex#L1)

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

# `cleanup_stale`

Clean up stale partial uploads older than `max_age` seconds.

# `receive`

Receive a file upload by streaming the body directly to disk.
Never loads the entire file into memory.

# `receive_chunk`

Receive a chunk of a resumable upload.
Returns `{:ok, :complete, file_info}` when all chunks received,
or `{:ok, :partial, progress}` when more chunks expected.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
