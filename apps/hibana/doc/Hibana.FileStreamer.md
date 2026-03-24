# `Hibana.FileStreamer`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/file_streamer.ex#L1)

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

# `send_file`

Send a file using zero-copy sendfile(2).
Supports range requests for resumable downloads and media seeking.

# `stream_chunks`

Stream chunks from an enumerable (e.g., File.stream!).
Uses chunked transfer encoding.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
