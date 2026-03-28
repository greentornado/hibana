defmodule RoutingBenchmark.Endpoint do
  use Hibana.Endpoint, otp_app: :routing_benchmark

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug RoutingBenchmark.Router
end
