defmodule RealtimeCluster.ClusterController do
  @moduledoc """
  Controller for cluster management and monitoring.
  """
  use Hibana.Controller

  @doc """
  Landing page with cluster info.
  """
  def index(conn) do
    json(conn, %{
      app: "RealtimeCluster",
      description: "Distributed cluster demo with PubSub and SSE",
      current_node: node() |> to_string(),
      connected_nodes: Node.list() |> length(),
      features: [
        "Automatic node discovery via gossip protocol",
        "Distributed PubSub for cross-node messaging",
        "LiveDashboard for cluster monitoring",
        "SSE streaming for real-time cluster events",
        "Multi-node chat with WebSocket"
      ],
      endpoints: [
        %{method: "GET", path: "/nodes", description: "List all connected nodes"},
        %{method: "GET", path: "/cluster/status", description: "Cluster topology and stats"},
        %{method: "POST", path: "/pubsub/publish", description: "Publish message to channel"},
        %{
          method: "GET",
          path: "/pubsub/subscribe/:channel",
          description: "Subscribe to channel via SSE"
        },
        %{method: "GET", path: "/pubsub/channels", description: "List active channels"},
        %{method: "GET", path: "/chat", description: "WebSocket chat endpoint"},
        %{method: "GET", path: "/events", description: "Cluster events SSE stream"},
        %{
          method: "GET",
          path: "/dashboard",
          description: "LiveDashboard (via LiveDashboard plugin)"
        }
      ],
      multi_node_demo: [
        "Terminal 1: PORT=4009 iex --name node1@127.0.0.1 -S mix run --no-halt",
        "Terminal 2: PORT=4010 iex --name node2@127.0.0.1 -S mix run --no-halt",
        "Watch nodes automatically discover each other via gossip"
      ]
    })
  end

  @doc """
  List all connected nodes in cluster.
  """
  def list_nodes(conn) do
    current = node()
    connected = Node.list()

    json(conn, %{
      current_node: current |> to_string(),
      connected_nodes: connected |> Enum.map(&to_string/1),
      node_count: length(connected) + 1,
      distributed: length(connected) > 0
    })
  end

  @doc """
  Get cluster status and topology.
  """
  def cluster_status(conn) do
    # Get cluster state from Hibana.Cluster
    nodes = [node() | Node.list()]

    json(conn, %{
      status: "active",
      topology: "fully_connected",
      nodes: nodes |> Enum.map(&to_string/1),
      node_count: length(nodes),
      self: node() |> to_string(),
      uptime: :erlang.statistics(:runtime) |> elem(0),
      memory: :erlang.memory()[:total]
    })
  end

  @doc """
  SSE stream for cluster events (node joins, leaves, messages).
  """
  def cluster_events(conn) do
    # Subscribe to cluster events
    Hibana.Cluster.subscribe("cluster:events")

    # Get the current process (conn handler) PID
    parent = self()

    # Spawn a process that listens to PubSub and forwards to SSE
    spawn(fn ->
      # Send initial connection event
      send(
        parent,
        {:sse_event, "connected",
         %{
           node: node() |> to_string(),
           message: "Connected to cluster event stream",
           timestamp: System.system_time(:second)
         }}
      )

      # Listen for cluster events and forward them
      forward_cluster_events(parent, 30_000)
    end)

    conn = Hibana.SSE.init(conn)
    Hibana.SSE.stream_loop(conn, keep_alive: 30_000)
  end

  # Forward cluster events from PubSub to SSE
  defp forward_cluster_events(parent, keep_alive_interval) do
    receive do
      {:cluster_event, event} ->
        send(parent, {:sse_event, "cluster", event})
        forward_cluster_events(parent, keep_alive_interval)

      {:pubsub_message, channel, message} ->
        send(parent, {:sse_event, "pubsub", %{channel: channel, message: message}})
        forward_cluster_events(parent, keep_alive_interval)

      :stop ->
        send(parent, :sse_close)
    after
      keep_alive_interval ->
        # Send keepalive event
        send(parent, {:sse_event, "keepalive", %{timestamp: System.system_time(:second)}})
        forward_cluster_events(parent, keep_alive_interval)
    end
  end
end
