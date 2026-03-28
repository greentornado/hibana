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
    
    conn = Hibana.SSE.init(conn)
    
    Hibana.SSE.stream_loop(conn, keep_alive: 30_000, fn send_event ->
      send_event.("subscribed", %{
        channel: channel,
        node: node() |> to_string(),
        message: "Subscribed to #{channel}"
      })
      
      # Listen for messages
      receive do
        {:pubsub_message, ^channel, data} ->
          send_event.("message", data)
          :continue
          
        after 30_000 ->
          send_event.("ping", %{timestamp: System.system_time(:second)})
          :continue
      end
    end)
  end
end