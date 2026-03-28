defmodule StreamingServer.Router do
  @moduledoc """
  Router demonstrating FileStreamer, ChunkedUpload, and SSE features.
  """
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  # Info endpoints
  get "/", StreamingServer.PageController, :index
  get "/features", StreamingServer.PageController, :features

  # File Streaming endpoints (FileStreamer with zero-copy and Range support)
  get "/files/:filename", StreamingServer.FileController, :download
  get "/stream/:filename", StreamingServer.FileController, :stream
  get "/download/:filename", StreamingServer.FileController, :download_with_range

  # File Upload endpoints (ChunkedUpload supporting 100GB+ files)
  post "/upload", StreamingServer.UploadController, :upload
  post "/upload/chunked", StreamingServer.UploadController, :chunked_upload

  # SSE (Server-Sent Events) streaming
  get "/events", StreamingServer.SSEController, :stream_events
  get "/progress/:upload_id", StreamingServer.SSEController, :upload_progress

  # Status endpoints
  get "/uploads", StreamingServer.UploadController, :list_uploads
end
