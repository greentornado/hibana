defmodule RealtimeCluster.Endpoint do
  use Hibana.Endpoint, otp_app: :realtime_cluster

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug RealtimeCluster.Router
end
