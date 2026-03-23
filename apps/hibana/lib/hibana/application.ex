defmodule Hibana.Application do
  @moduledoc """
  Hibana application supervision tree.

  ## Supervision Structure

  The application starts:

  - `Hibana.Plugin.Registry` - Registry for plugins
  - `Hibana.Plugin.Supervisor` - DynamicSupervisor for plugins
  - `Hibana.Endpoint` - HTTP endpoint

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
  | Endpoint | Worker | HTTP server |
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Hibana.Plugin.Registry,
      {DynamicSupervisor, strategy: :one_for_one, name: Hibana.Plugin.Supervisor},
      Hibana.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Hibana.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
