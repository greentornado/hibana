defmodule RoutingBenchmark.Router do
  @moduledoc """
  Demonstrates CompiledRouter with 1000+ routes using O(1) pattern matching.

  This router generates routes programmatically at compile time to showcase
  the constant-time dispatch performance of CompiledRouter vs traditional routing.
  """
  use Hibana.CompiledRouter

  plug Hibana.Plugins.BodyParser

  # Generate 500 static routes: /static/1, /static/2, ..., /static/500
  for i <- 1..500 do
    get "/static/#{i}", RoutingBenchmark.BenchmarkController, :static_route
  end

  # Generate 300 parameterized routes: /users/1, /users/2, ..., /users/300
  for i <- 1..300 do
    get "/user/#{i}", RoutingBenchmark.BenchmarkController, :user_route
  end

  # Generate 100 nested parameterized routes: /api/v1/items/1, etc
  for version <- 1..2 do
    for i <- 1..50 do
      get "/api/v#{version}/item/#{i}", RoutingBenchmark.BenchmarkController, :api_route
    end
  end

  # Generate 100 wildcard pattern routes: /files/docs/1, /files/images/2, etc
  for category <- ["docs", "images", "videos", "audio", "data"] do
    for i <- 1..20 do
      get "/files/#{category}/#{i}", RoutingBenchmark.BenchmarkController, :file_route
    end
  end

  # Benchmark and info endpoints
  get "/", RoutingBenchmark.BenchmarkController, :index
  get "/routes", RoutingBenchmark.BenchmarkController, :list_routes
  get "/benchmark", RoutingBenchmark.BenchmarkController, :run_benchmark
  get "/perf/:route_num", RoutingBenchmark.BenchmarkController, :perf_test
  get "/compare", RoutingBenchmark.BenchmarkController, :compare_routing
end
