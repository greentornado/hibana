defmodule RealtimeCluster.ChatSocket do
  @moduledoc """
  WebSocket handler for multi-node chat.
  Messages are distributed across cluster via PubSub.
  """
  use Hibana.WebSocket

  @channel "chat:cluster"

  @impl true
  def init(conn, _opts) do
    user_id = generate_user_id()
    state = %{user_id: user_id, node: node()}

    # Subscribe to cluster-wide chat channel
    Hibana.Cluster.subscribe(@channel)

    {:ok, conn, state}
  end

  @impl true
  def handle_connect(_headers, state) do
    # Broadcast join message to all nodes
    Hibana.Cluster.publish(@channel, %{
      type: "join",
      user: state.user_id,
      node: state.node |> to_string(),
      timestamp: System.system_time(:second)
    })

    {:ok, state}
  end

  @impl true
  def handle_in(message, state) do
    # Broadcast message to all nodes in cluster
    Hibana.Cluster.publish(@channel, %{
      type: "message",
      user: state.user_id,
      node: state.node |> to_string(),
      message: message,
      timestamp: System.system_time(:second)
    })

    {:ok, state}
  end

  @impl true
  def handle_info({:pubsub_message, @channel, data}, state) do
    # Received message from another node, send to WebSocket client
    {:push, {:text, Jason.encode!(data)}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end

  @impl true
  def handle_disconnect(_reason, state) do
    # Broadcast leave message
    Hibana.Cluster.publish(@channel, %{
      type: "leave",
      user: state.user_id,
      node: state.node |> to_string(),
      timestamp: System.system_time(:second)
    })

    :ok
  end

  defp generate_user_id do
    :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)
  end
end
