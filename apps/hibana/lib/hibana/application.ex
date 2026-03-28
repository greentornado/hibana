defmodule Hibana.Application do
  @moduledoc """
  Hibana application supervision tree.

  ## Supervision Structure

  The application starts:

  - `Hibana.Plugin.Registry` - Registry for plugins
  - `Hibana.Plugin.Supervisor` - DynamicSupervisor for plugins
  - `Hibana.Queue` - Background job queue
  - `Hibana.OTPCache` - OTP-based cache
  - `Hibana.Endpoint` - HTTP endpoint

  Optional components that can be added to your own supervision tree:
  - `Hibana.PersistentQueue` - Disk-backed persistent queue
  - `Hibana.CircuitBreaker` - Circuit breaker for external calls

  ## Usage

  Add to your Mix config:

      def application do
        [
          extra_applications: [:logger],
          mod: {Hibana.Application, []}
        ]
      end

  ## Children

  | Child | Type | Description |
  |-------|------|-------------|
  | Plugin.Registry | Registry | Plugin registration |
  | Plugin.Supervisor | DynamicSupervisor | Plugin supervision |
  | Queue | Worker | Background job queue |
  | OTPCache | Worker | In-memory cache with TTL |
  | Endpoint | Worker | HTTP server |
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hibana.Plugin.Registry,
      {DynamicSupervisor, strategy: :one_for_one, name: Hibana.Plugin.Supervisor},
      Hibana.Queue,
      Hibana.OTPCache,
      Hibana.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Hibana.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
