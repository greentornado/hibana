defmodule SystemMonitor.APIController do
  use Hibana.Controller

  def snapshot(conn) do
    data = SystemMonitor.Collector.latest_snapshot()
    json(conn, data)
  end

  def processes(conn) do
    procs = SystemMonitor.Collector.top_processes(50)
    json(conn, %{processes: procs, count: length(procs)})
  end

  def ets_tables(conn) do
    tables = SystemMonitor.Collector.ets_tables()
    json(conn, %{tables: tables, count: length(tables)})
  end

  def memory(conn) do
    mem = SystemMonitor.Collector.memory_detail()
    json(conn, mem)
  end
end
