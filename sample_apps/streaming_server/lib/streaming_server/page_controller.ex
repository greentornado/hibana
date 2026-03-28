defmodule StreamingServer.PageController do
  @moduledoc """
  Landing page and documentation for streaming features.
  """
  use Hibana.Controller

  def index(conn, _params) do
    json(conn, %{
      app: "StreamingServer",
      description: "File streaming, chunked uploads, and SSE demo",
      features: [
        "Zero-copy file streaming with sendfile(2)",
        "HTTP Range requests for video seeking",
        "Chunked uploads supporting 100GB+ files",
        "Server-Sent Events for real-time updates",
        "Progress tracking and resumable downloads"
      ],
      endpoints: [
        %{method: "GET", path: "/features", description: "List all streaming features"},
        %{method: "GET", path: "/files/:filename", description: "Download file (simple)"},
        %{method: "GET", path: "/stream/:filename", description: "Stream with Range support"},
        %{method: "POST", path: "/upload", description: "Standard file upload"},
        %{method: "POST", path: "/upload/chunked", description: "Large file chunked upload"},
        %{method: "GET", path: "/events", description: "SSE event stream"},
        %{method: "GET", path: "/progress/:upload_id", description: "Upload progress via SSE"},
        %{method: "GET", path: "/uploads", description: "List uploaded files"}
      ],
      examples: [
        %{
          description: "Download with curl",
          command: "curl -O http://localhost:4008/files/sample.txt"
        },
        %{
          description: "Resume download (Range header)",
          command: "curl -H 'Range: bytes=1024-2047' -O http://localhost:4008/stream/sample.txt"
        },
        %{
          description: "Upload file",
          command: "curl -X POST -F 'file=@large_video.mp4' http://localhost:4008/upload/chunked"
        },
        %{description: "Listen to SSE events", command: "curl http://localhost:4008/events"}
      ]
    })
  end

  def features(conn, _params) do
    json(conn, %{
      features: [
        %{
          name: "FileStreamer",
          description: "Zero-copy file streaming using sendfile(2) syscall",
          capabilities: [
            "Direct kernel-space to socket transfer (no user-space copying)",
            "HTTP Range request support for resumable downloads",
            "Video seeking without downloading entire file",
            "ETag-based caching for conditional requests",
            "MIME type auto-detection"
          ]
        },
        %{
          name: "ChunkedUpload",
          description: "Streaming file uploads for unlimited file sizes",
          capabilities: [
            "Stream chunks directly to disk (no memory buffering)",
            "Support for 100GB+ file uploads",
            "Progress callbacks for real-time tracking",
            "Automatic chunk assembly",
            "Configurable chunk sizes (default 8MB)"
          ]
        },
        %{
          name: "SSE (Server-Sent Events)",
          description: "Real-time server-to-client streaming",
          capabilities: [
            "HTTP-based (works through proxies/firewalls)",
            "Automatic reconnection by browsers",
            "Event IDs for replay/resume",
            "Multiple event types",
            "Automatic keep-alive to prevent timeouts"
          ]
        }
      ]
    })
  end
end
