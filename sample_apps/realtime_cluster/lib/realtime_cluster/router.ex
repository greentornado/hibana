defmodule RealtimeCluster.Router do
  @moduledoc """
  Router for cluster demo with PubSub and SSE.
  """
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  # Info endpoints
  get "/", RealtimeCluster.ClusterController, :index
  get "/nodes", RealtimeCluster.ClusterController, :list_nodes
  get "/cluster/status", RealtimeCluster.ClusterController, :cluster_status

  # PubSub demo
  post "/pubsub/publish", RealtimeCluster.PubSubController, :publish
  get "/pubsub/subscribe/:channel", RealtimeCluster.PubSubController, :subscribe_sse
  get "/pubsub/channels", RealtimeCluster.PubSubController, :list_channels

  # Chat WebSocket
  get "/chat", RealtimeCluster.ChatSocket, :upgrade

  # SSE cluster events
  get "/events", RealtimeCluster.ClusterController, :cluster_events
end
