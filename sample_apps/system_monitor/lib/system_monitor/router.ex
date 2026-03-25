defmodule SystemMonitor.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.ErrorHandler

  get("/", SystemMonitor.PageController, :index)
  get("/events", SystemMonitor.SSEController, :stream)
  get("/api/snapshot", SystemMonitor.APIController, :snapshot)
  get("/api/processes", SystemMonitor.APIController, :processes)
  get("/api/ets", SystemMonitor.APIController, :ets_tables)
  get("/api/memory", SystemMonitor.APIController, :memory)
end
