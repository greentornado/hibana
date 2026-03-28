defmodule ResilientServices.Router do
  @moduledoc """
  Router demonstrating CircuitBreaker and PersistentQueue resilience patterns.
  """
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  # Info endpoints
  get "/", ResilientServices.ResilienceController, :index
  get "/resilience/stats", ResilientServices.ResilienceController, :stats

  # Circuit Breaker demo
  get "/circuit/status", ResilientServices.CircuitController, :status
  post "/circuit/call", ResilientServices.CircuitController, :call_api
  post "/circuit/trip", ResilientServices.CircuitController, :trip_circuit
  post "/circuit/reset", ResilientServices.CircuitController, :reset_circuit

  # PersistentQueue demo
  post "/jobs", ResilientServices.QueueController, :submit_job
  get "/jobs", ResilientServices.QueueController, :list_jobs
  get "/jobs/stats", ResilientServices.QueueController, :queue_stats
  post "/jobs/process", ResilientServices.QueueController, :process_jobs

  # Demo scenarios
  get "/demo/failure", ResilientServices.DemoController, :simulate_failure
  get "/demo/recovery", ResilientServices.DemoController, :simulate_recovery
end
