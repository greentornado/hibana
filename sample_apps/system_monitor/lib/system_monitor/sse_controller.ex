defmodule SystemMonitor.SSEController do
  use Hibana.Controller

  def stream(conn) do
    conn = Hibana.SSE.init(conn)

    SystemMonitor.Collector.subscribe(self())

    stream_loop(conn)
  end

  defp stream_loop(conn) do
    receive do
      {:metrics, data} ->
        case Hibana.SSE.send_event(conn, "metrics", data) do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end
    after
      30_000 ->
        case Hibana.SSE.send_comment(conn, "keepalive") do
          {:ok, conn} -> stream_loop(conn)
          {:error, _} -> conn
        end
    end
  end
end
