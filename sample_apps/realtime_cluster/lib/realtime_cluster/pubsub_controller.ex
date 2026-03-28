defmodule RealtimeCluster.PubSubController do
  @moduledoc """
  Controller for distributed PubSub operations.
  """
  use Hibana.Controller

  @doc """
  List active PubSub channels.
  """
  def list_channels(conn, _params) do
    # In real implementation, track channels in ETS
    channels = [
      %{name: "chat:lobby", subscribers: 0, messages: 0},
      %{name: "chat:tech", subscribers: 0, messages: 0},
      %{name: "system:events", subscribers: 0, messages: 0}
    ]

    json(conn, %{channels: channels})
  end

  @doc """
  Publish message to a channel (distributed to all nodes).
  """
  def publish(conn, params) do
    channel = params["channel"] || "default"
    message = params["message"] || "Hello from #{node()}"

    # Publish to all nodes in cluster
    Hibana.Cluster.publish(channel, %{
      message: message,
      from: node() |> to_string(),
      timestamp: System.system_time(:second)
    })

    json(conn, %{
      status: "published",
      channel: channel,
      message: message,
      nodes_reached: length(Node.list()) + 1
    })
  end

  @doc """
  Subscribe to channel via SSE (receives messages from all nodes).
  """
  def subscribe_sse(conn, params) do
    channel = params["channel"] || "default"

    # Subscribe to channel
    Hibana.Cluster.subscribe(channel)

    # Get parent process for sending events
    parent = self()

    # Spawn a process that listens to PubSub and forwards to SSE
    spawn(fn ->
      # Send initial subscription event
      send(
        parent,
        {:sse_event, "subscribed",
         %{
           channel: channel,
           node: node() |> to_string(),
           message: "Subscribed to #{channel}"
         }}
      )

      # Listen for PubSub messages and forward them
      forward_pubsub_messages(parent, channel, 30_000)
    end)

    conn = Hibana.SSE.init(conn)
    Hibana.SSE.stream_loop(conn, keep_alive: 30_000)
  end

  # Forward PubSub messages to SSE
  defp forward_pubsub_messages(parent, channel, keep_alive_interval) do
    receive do
      {:pubsub_message, ^channel, data} ->
        send(parent, {:sse_event, "message", data})
        forward_pubsub_messages(parent, channel, keep_alive_interval)

      :stop ->
        send(parent, :sse_close)
    after
      keep_alive_interval ->
        # Send ping event
        send(parent, {:sse_event, "ping", %{timestamp: System.system_time(:second)}})
        forward_pubsub_messages(parent, channel, keep_alive_interval)
    end
  end
end
