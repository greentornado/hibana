defmodule StreamingServer.SSEController do
  @moduledoc """
  Controller demonstrating Server-Sent Events (SSE) for real-time streaming.

  Features:
  - Chunked transfer encoding
  - Automatic keep-alive
  - Event types and IDs
  - Browser-compatible formatting
  """
  use Hibana.Controller

  @doc """
  SSE endpoint that streams events to the client.
  """
  def stream_events(conn) do
    # Get the current process PID
    parent = self()

    # Spawn a process to send events
    spawn(fn ->
      # Send welcome event
      send(
        parent,
        {:sse_event, "connected",
         %{
           message: "SSE connection established",
           timestamp: System.system_time(:second)
         }}
      )

      # Stream periodic updates
      stream_updates(parent, 10)
    end)

    # Initialize SSE and enter streaming loop
    conn = Hibana.SSE.init(conn)
    Hibana.SSE.stream_loop(conn, keep_alive: 30_000)
  end

  @doc """
  SSE endpoint for upload progress tracking.
  """
  def upload_progress(conn) do
    upload_id = conn.params["upload_id"]
    parent = self()

    # Spawn background process to simulate upload progress
    spawn(fn -> simulate_upload_progress(parent, upload_id) end)

    conn = Hibana.SSE.init(conn)
    Hibana.SSE.stream_loop(conn, keep_alive: 15_000)
  end

  # Helper to stream updates
  defp stream_updates(parent, remaining) when remaining > 0 do
    # Wait between updates
    Process.sleep(2000)

    # Send update event
    send(
      parent,
      {:sse_event, "update",
       %{
         counter: 11 - remaining,
         timestamp: System.system_time(:second),
         data: "Server update ##{11 - remaining}"
       }}
    )

    # Continue or send completion
    if remaining > 1 do
      stream_updates(parent, remaining - 1)
    else
      send(parent, {:sse_event, "complete", %{message: "Stream finished", total: 10}})
      send(parent, :sse_close)
    end
  end

  # Helper to simulate upload progress
  defp simulate_upload_progress(parent, upload_id) do
    Enum.each(0..100//10, fn percent ->
      send(parent, {:sse_event, "progress",
       %{
         upload_id: upload_id,
         percent: percent,
         # Simulate MB uploaded
         bytes_uploaded: percent * 1_048_576,
         total_bytes: 100 * 1_048_576,
         eta_seconds: 100 - percent
       }})

      # Update every 500ms
      Process.sleep(500)
    end)

    send(
      parent,
      {:sse_event, "complete", %{upload_id: upload_id, percent: 100, message: "Upload complete"}}
    )

    send(parent, :sse_close)
  end
end
