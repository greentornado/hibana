defmodule Mix.Tasks.Bench do
  @moduledoc """
  Mix task for route performance benchmarking.

  ## Usage

      mix bench --routes "/,/users,/api/health" --concurrency 4 --duration 5

  ## Options

    - `--routes` - comma-separated list of routes to benchmark (default: "/")
    - `--concurrency` - number of concurrent workers (default: 1)
    - `--duration` - duration in seconds (default: 3)
    - `--method` - HTTP method (default: "GET")
    - `--router` - router module (default: auto-detect from app)
  """

  use Mix.Task

  @shortdoc "Benchmark route performance"

  @doc """
  Runs the route performance benchmark.

  ## Parameters

    - `args` - Command-line arguments with `--routes`, `--concurrency`, `--duration`, `--method`, `--router` flags
  """
  @impl true
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          routes: :string,
          concurrency: :integer,
          duration: :integer,
          method: :string,
          router: :string
        ]
      )

    Mix.Task.run("app.start")

    routes = opts |> Keyword.get(:routes, "/") |> String.split(",") |> Enum.map(&String.trim/1)
    concurrency = Keyword.get(opts, :concurrency, 1)
    duration = Keyword.get(opts, :duration, 3)
    method = opts |> Keyword.get(:method, "GET") |> String.downcase() |> parse_http_method()

    router =
      case Keyword.get(opts, :router) do
        nil -> detect_router()
        mod -> Module.concat([mod])
      end

    unless router do
      Mix.shell().error("No router module found. Use --router MyApp.Router")
      exit(:normal)
    end

    Mix.shell().info("""

    ==========================================
      Hibana Benchmark Runner
    ==========================================
      Router:      #{inspect(router)}
      Routes:      #{Enum.join(routes, ", ")}
      Concurrency: #{concurrency}
      Duration:    #{duration}s
      Method:      #{method |> to_string() |> String.upcase()}
    ==========================================
    """)

    Enum.each(routes, fn route ->
      bench_route(router, method, route, concurrency, duration)
    end)
  end

  defp bench_route(router, method, route, concurrency, duration_sec) do
    Mix.shell().info("\n  Benchmarking #{String.upcase(to_string(method))} #{route}...")
    Mix.shell().info("  #{String.duplicate("-", 40)}")

    duration_ms = duration_sec * 1_000
    parent = self()

    # Spawn concurrent workers
    workers =
      for _i <- 1..concurrency do
        Task.async(fn ->
          run_worker(router, method, route, duration_ms, parent)
        end)
      end

    # Collect results
    results = Enum.flat_map(workers, fn task -> Task.await(task, duration_ms + 5_000) end)

    if length(results) == 0 do
      Mix.shell().info("  No requests completed.")
      return()
    end

    # Compute statistics
    total_requests = length(results)
    total_time_s = duration_sec

    latencies = results |> Enum.sort()
    rps = Float.round(total_requests / total_time_s, 1)
    avg = Float.round(Enum.sum(latencies) / total_requests, 2)
    min_lat = Enum.min(latencies)
    max_lat = Enum.max(latencies)
    p50 = percentile(latencies, 50)
    p95 = percentile(latencies, 95)
    p99 = percentile(latencies, 99)

    Mix.shell().info("""
      Requests:    #{total_requests}
      RPS:         #{rps}
      Avg Latency: #{format_us(avg)}
      Min Latency: #{format_us(min_lat)}
      Max Latency: #{format_us(max_lat)}
      P50:         #{format_us(p50)}
      P95:         #{format_us(p95)}
      P99:         #{format_us(p99)}
    """)
  end

  defp run_worker(router, method, route, duration_ms, _parent) do
    deadline = System.monotonic_time(:millisecond) + duration_ms
    run_loop(router, method, route, deadline, [])
  end

  defp run_loop(router, method, route, deadline, acc) do
    now = System.monotonic_time(:millisecond)

    if now >= deadline do
      acc
    else
      conn = Plug.Test.conn(method, route)
      start = System.monotonic_time(:microsecond)

      try do
        router.call(conn, router.init([]))
      rescue
        _ -> :error
      end

      elapsed = System.monotonic_time(:microsecond) - start
      run_loop(router, method, route, deadline, [elapsed | acc])
    end
  end

  defp percentile(sorted_list, p) do
    len = length(sorted_list)
    index = max(0, round(len * p / 100) - 1)
    Enum.at(sorted_list, index, 0) |> to_float()
  end

  defp to_float(v) when is_integer(v), do: v * 1.0
  defp to_float(v) when is_float(v), do: v

  defp format_us(us) when us < 1_000, do: "#{Float.round(us, 1)}µs"
  defp format_us(us) when us < 1_000_000, do: "#{Float.round(us / 1_000, 2)}ms"
  defp format_us(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  defp detect_router do
    app = Mix.Project.config()[:app]

    if app do
      module = app |> to_string() |> Macro.camelize()
      router_module = Module.concat([module, "Router"])

      if Code.ensure_loaded?(router_module) do
        router_module
      else
        nil
      end
    else
      nil
    end
  end

  defp return, do: :ok

  defp parse_http_method("get"), do: :get
  defp parse_http_method("post"), do: :post
  defp parse_http_method("put"), do: :put
  defp parse_http_method("patch"), do: :patch
  defp parse_http_method("delete"), do: :delete
  defp parse_http_method("head"), do: :head
  defp parse_http_method("options"), do: :options
  defp parse_http_method(other), do: raise("Unknown HTTP method: #{other}")
end
