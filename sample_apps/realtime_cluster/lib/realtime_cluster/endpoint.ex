defmodule RealtimeCluster.Endpoint do
  @moduledoc """
  Endpoint with LiveDashboard for monitoring distributed cluster.
  """
  use Hibana.Endpoint, otp_app: :realtime_cluster

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug Hibana.Plugins.LiveDashboard
  plug RealtimeCluster.Router
end
