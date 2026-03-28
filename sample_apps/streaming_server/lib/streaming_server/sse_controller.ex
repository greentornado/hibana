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
  def stream_events(conn, _params) do
    # Initialize SSE connection
    conn = Hibana.SSE.init(conn)
    
    # Stream events from process mailbox
    Hibana.SSE.stream_loop(conn, keep_alive: 30_000, fn send_event ->
      # Send welcome event
      send_event.("connected", %{message: "SSE connection established", timestamp: System.system_time(:second)})
      
      # Stream periodic updates
      stream_updates(send_event, 10)
    end)
  end

  @doc """
  SSE endpoint for upload progress tracking.
  """
  def upload_progress(conn, params) do
    upload_id = params["upload_id"]
    
    conn = Hibana.SSE.init(conn)
    
    Hibana.SSE.stream_loop(conn, keep_alive: 15_000, fn send_event ->
      # Simulate progress updates (in real app, read from actual upload state)
      simulate_progress(send_event, upload_id, 100)
    end)
  end

  # Helper to stream updates
  defp stream_updates(send_event, remaining) when remaining > 0 do
    # Simulate work or wait for real events
    Process.sleep(2000)
    
    # Send event
    send_event.("update", %{
      counter: 11 - remaining,
      timestamp: System.system_time(:second),
      data: "Server update ##{11 - remaining}"
    })
    
    # Continue or stop
    if remaining > 1 do
      stream_updates(send_event, remaining - 1)
    else
      # Send completion event
      send_event.("complete", %{message: "Stream finished", total: 10})
      :ok
    end
  end

  # Helper to simulate upload progress
  defp simulate_progress(send_event, upload_id, remaining) when remaining > 0 do
    progress = 100 - remaining
    
    send_event.("progress", %{
      upload_id: upload_id,
      percent: progress,
      bytes_uploaded: progress * 1048576,  # Simulate MB uploaded
      total_bytes: 100 * 1048576,
      eta_seconds: remaining
    })
    
    if remaining > 1 do
      Process.sleep(500)  # Update every 500ms
      simulate_progress(send_event, upload_id, remaining - 1)
    else
      send_event.("complete", %{upload_id: upload_id, percent: 100, message: "Upload complete"})
      :ok
    end
  end
end