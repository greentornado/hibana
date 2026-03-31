defmodule Hibana.Plugins.Metrics do
  @moduledoc """
  Metrics and Telemetry plugin for monitoring and observability with histogram support.

  ## Features

  - Request duration tracking via :telemetry with histogram buckets
  - Request counting by method, path, and status
  - Prometheus-compatible metrics endpoint with histogram percentiles
  - Zero-configuration defaults
  - Configurable histogram buckets

  ## Usage

      # Basic usage (metrics at /metrics)
      plug Hibana.Plugins.Metrics

      # With custom endpoint and histogram buckets
      plug Hibana.Plugins.Metrics, 
        endpoint: "/admin/metrics",
        duration_buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

  ## Telemetry Events

  Emits the following :telemetry events:

  ### [:hibana, :request, :duration]
  Fired on each request completion with duration in milliseconds.

      :telemetry.execute(
        [:hibana, :request, :duration],
        %{duration: 123},
        %{method: "GET", path: "/users", status: 200}
      )

  ### [:hibana, :request, :total]
  Counter incremented on each request.

      :telemetry.execute(
        [:hibana, :request, :total],
        %{count: 1},
        %{method: "GET", path: "/users", status: 200}
      )

  ## Prometheus Endpoint

  GET /metrics returns Prometheus-formatted metrics:

      # HELP hibana_requests_total Total requests
      # TYPE hibana_requests_total counter
      hibana_requests_total 1234

      # HELP hibana_request_duration_ms Request duration histogram
      # TYPE hibana_request_duration_ms histogram
      hibana_request_duration_ms_bucket{le="10"} 42
      hibana_request_duration_ms_bucket{le="50"} 150
      hibana_request_duration_ms_bucket{le="100"} 450
      hibana_request_duration_ms_bucket{le="+Inf"} 1234
      hibana_request_duration_ms_sum 123456
      hibana_request_duration_ms_count 1234

  ## Options

  - `:enabled` - Enable/disable metrics (default: `true`)
  - `:endpoint` - Metrics endpoint path (default: `"/metrics"`)
  - `:duration_buckets` - Histogram bucket boundaries in ms (default: `[10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]`)

  ## Integration with Prometheus

  Can be scraped by Prometheus:

      scrape_configs:
        - job_name: 'hibana'
          static_configs:
            - targets: ['localhost:4000']
          metrics_path: '/metrics'
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  # Default histogram buckets in milliseconds
  @default_buckets [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]

  @doc """
  Sets up the metrics ETS table and attaches telemetry handlers.

  Creates the `:metrics` ETS table with histogram support and attaches handlers for
  `[:hibana, :request, :total]` and `[:hibana, :request, :duration]` events.
  Safe to call multiple times.

  ## Options

    - `:buckets` - Histogram bucket boundaries (default: #{inspect(@default_buckets)})

  ## Returns

  `:ok`
  """
  def setup(opts \\ []) do
    buckets = Keyword.get(opts, :buckets, @default_buckets)

    case :ets.whereis(:metrics) do
      :undefined ->
        # Create ETS table with histogram bucket storage
        :ets.new(:metrics, [:named_table, :set, :public, write_concurrency: true])
        :ets.insert(:metrics, {:requests_total, 0})
        :ets.insert(:metrics, {:duration_sum, 0})
        :ets.insert(:metrics, {:duration_count, 0})

        # Initialize histogram buckets
        Enum.each(buckets, fn bucket ->
          :ets.insert(:metrics, {{:duration_bucket, bucket}, 0})
        end)

        # Store bucket configuration
        :ets.insert(:metrics, {:duration_buckets, buckets})

      _ ->
        :ok
    end

    # Attach telemetry handlers
    attach_handlers()

    :ok
  end

  defp attach_handlers do
    # Total requests counter
    try do
      :telemetry.attach(
        "hibana_metrics_counter",
        [:hibana, :request, :total],
        &handle_telemetry_event/4,
        nil
      )
    rescue
      _ -> :ok
    end

    # Duration histogram
    try do
      :telemetry.attach(
        "hibana_metrics_duration",
        [:hibana, :request, :duration],
        &handle_duration_event/4,
        nil
      )
    rescue
      _ -> :ok
    end
  end

  @doc """
  Initializes the metrics system by calling `setup/0`.

  Returns `:ignore` since this is a one-time setup task, not a long-running process.
  """
  @impl true
  def start_link(opts \\ []) do
    setup(opts)
    :ignore
  end

  defp handle_telemetry_event([:hibana, :request, :total], _measurements, metadata, _config) do
    try do
      # Update total counter
      :ets.update_counter(:metrics, :requests_total, {2, 1})

      # Update method-specific counter if metadata provided
      if metadata[:method] do
        method_key = {:requests_by_method, metadata[:method]}
        :ets.update_counter(:metrics, method_key, {2, 1}, {method_key, 0})
      end

      # Update status-specific counter if metadata provided
      if metadata[:status] do
        status_key = {:requests_by_status, metadata[:status]}
        :ets.update_counter(:metrics, status_key, {2, 1}, {status_key, 0})
      end
    rescue
      _ -> :ok
    end
  end

  defp handle_duration_event([:hibana, :request, :duration], measurements, _metadata, _config) do
    try do
      duration = measurements[:duration] || 0

      # Update sum and count
      :ets.update_counter(:metrics, :duration_sum, {2, duration}, {:duration_sum, 0})
      :ets.update_counter(:metrics, :duration_count, {2, 1})

      # Update histogram buckets - optimized to find insertion point first
      case :ets.lookup(:metrics, :duration_buckets) do
        [{:duration_buckets, buckets}] ->
          # Find the first bucket that exceeds the duration
          # All subsequent buckets should also be incremented (cumulative histogram)
          idx = Enum.find_index(buckets, fn bucket -> duration <= bucket end)

          if idx do
            # Update from idx to end (all buckets >= duration)
            buckets_to_update = Enum.drop(buckets, idx)

            Enum.each(buckets_to_update, fn bucket ->
              bucket_key = {:duration_bucket, bucket}
              :ets.update_counter(:metrics, bucket_key, {2, 1}, {bucket_key, 0})
            end)
          end

          # Always update the +Inf bucket (last one implicitly handled by total count)
          :ok

        _ ->
          :ok
      end
    rescue
      _ -> :ok
    end
  end

  @impl true
  def init(opts) do
    # Setup metrics with configured buckets
    buckets = Keyword.get(opts, :duration_buckets, @default_buckets)
    setup(buckets: buckets)

    %{
      enabled: Keyword.get(opts, :enabled, true),
      endpoint: Keyword.get(opts, :endpoint, "/metrics"),
      buckets: buckets
    }
  end

  @impl true
  def call(conn, %{endpoint: endpoint, enabled: true}) do
    if conn.request_path == endpoint do
      metrics(conn)
    else
      start_timer(conn)
    end
  end

  @impl true
  def call(conn, %{enabled: false}) do
    start_timer(conn)
  end

  defp start_timer(conn) do
    start = System.monotonic_time(:millisecond)

    conn
    |> assign(:request_start, start)
    |> Plug.Conn.register_before_send(fn conn ->
      if start do
        duration = System.monotonic_time(:millisecond) - start

        :telemetry.execute([:hibana, :request, :duration], %{duration: duration}, %{
          method: conn.method,
          path: conn.request_path,
          status: conn.status
        })

        :telemetry.execute([:hibana, :request, :total], %{count: 1}, %{
          method: conn.method,
          path: conn.request_path,
          status: conn.status
        })
      end

      conn
    end)
  end

  defp metrics(conn) do
    metrics_data = collect_metrics()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, format_prometheus(metrics_data))
    |> halt()
  end

  defp collect_metrics do
    %{
      requests_total: safe_get_counter(:requests_total),
      duration_sum: safe_get_counter(:duration_sum),
      duration_count: safe_get_counter(:duration_count),
      duration_buckets: get_duration_buckets(),
      requests_by_method: get_requests_by_method(),
      requests_by_status: get_requests_by_status()
    }
  end

  defp get_duration_buckets do
    try do
      case :ets.lookup(:metrics, :duration_buckets) do
        [{:duration_buckets, buckets}] ->
          Enum.map(buckets, fn bucket ->
            count = safe_get_counter({:duration_bucket, bucket})
            {bucket, count}
          end)

        _ ->
          []
      end
    rescue
      _ -> []
    end
  end

  defp get_requests_by_method do
    try do
      :metrics
      |> :ets.select([{{{:requests_by_method, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])
      |> Map.new()
    rescue
      _ -> %{}
    end
  end

  defp get_requests_by_status do
    try do
      :metrics
      |> :ets.select([{{{:requests_by_status, :"$1"}, :"$2"}, [], [{{:"$1", :"$2"}}]}])
      |> Map.new()
    rescue
      _ -> %{}
    end
  end

  defp safe_get_counter(key) do
    try do
      case :ets.lookup(:metrics, key) do
        [{^key, value}] -> value
        _ -> 0
      end
    rescue
      ArgumentError -> 0
    end
  end

  defp format_prometheus(data) do
    lines = []

    # Total requests counter
    lines = [
      "# HELP hibana_requests_total Total requests",
      "# TYPE hibana_requests_total counter",
      "hibana_requests_total #{data.requests_total}"
      | lines
    ]

    # Requests by method
    if map_size(data.requests_by_method) > 0 do
      lines = [
        "",
        "# HELP hibana_requests_by_method_total Total requests by HTTP method",
        "# TYPE hibana_requests_by_method_total counter"
        | lines
      ]

      lines =
        Enum.reduce(data.requests_by_method, lines, fn {method, count}, acc ->
          ["hibana_requests_by_method_total{method=\"#{method}\"} #{count}" | acc]
        end)
    end

    # Requests by status
    if map_size(data.requests_by_status) > 0 do
      lines = [
        "",
        "# HELP hibana_requests_by_status_total Total requests by HTTP status",
        "# TYPE hibana_requests_by_status_total counter"
        | lines
      ]

      lines =
        Enum.reduce(data.requests_by_status, lines, fn {status, count}, acc ->
          ["hibana_requests_by_status_total{status=\"#{status}\"} #{count}" | acc]
        end)
    end

    # Duration histogram
    lines = [
      "",
      "# HELP hibana_request_duration_ms Request duration histogram in milliseconds",
      "# TYPE hibana_request_duration_ms histogram"
      | lines
    ]

    # Histogram buckets
    {lines, cumulative} =
      Enum.reduce(data.duration_buckets, {lines, 0}, fn {bucket, count}, {acc, cum} ->
        new_cum = cum + count
        acc = ["hibana_request_duration_ms_bucket{le=\"#{bucket}\"} #{new_cum}" | acc]
        {acc, new_cum}
      end)

    # +Inf bucket
    lines = ["hibana_request_duration_ms_bucket{le=\"+Inf\"} #{data.duration_count}" | lines]

    # Sum and count
    lines = [
      "hibana_request_duration_ms_sum #{data.duration_sum}",
      "hibana_request_duration_ms_count #{data.duration_count}"
      | lines
    ]

    lines
    |> Enum.reverse()
    |> Enum.join("\n")
    |> Kernel.<>("\n")
  end
end
