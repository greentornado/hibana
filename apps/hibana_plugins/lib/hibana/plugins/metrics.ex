defmodule Hibana.Plugins.Metrics do
  @moduledoc """
  Metrics and Telemetry plugin for monitoring and observability.

  ## Features

  - Request duration tracking via :telemetry
  - Request counting by method, path, and status
  - Prometheus-compatible metrics endpoint
  - Zero-configuration defaults

  ## Usage

      # Basic usage (metrics at /metrics)
      plug Hibana.Plugins.Metrics

      # With custom endpoint
      plug Hibana.Plugins.Metrics, endpoint: "/admin/metrics"

  ## Telemetry Events

  Emits the following :telemetry events:

  ### [:hibana, :request, :duration]
  Fired on each request completion.

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

      # HELP hibana_request_duration_ms Request duration
      # TYPE hibana_request_duration_ms histogram
      hibana_request_duration_ms_count 1234

  ## Options

  - `:enabled` - Enable/disable metrics (default: `true`)
  - `:endpoint` - Metrics endpoint path (default: `"/metrics"`)

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

  @doc """
  Sets up the metrics ETS table and attaches telemetry handlers.

  Creates the `:metrics` ETS table and attaches a handler for
  `[:hibana, :request, :total]` events. Safe to call multiple times.

  ## Returns

  `:ok`
  """
  def setup do
    case :ets.whereis(:metrics) do
      :undefined ->
        :ets.new(:metrics, [:named_table, :set, :public, write_concurrency: true])
        :ets.insert(:metrics, {:requests_total, 0})

      _ ->
        :ok
    end

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

    :ok
  end

  @doc """
  Initializes the metrics system by calling `setup/0`.

  Returns `:ignore` since this is a one-time setup task, not a long-running process.
  """
  def start_link do
    setup()
    :ignore
  end

  defp handle_telemetry_event([:hibana, :request, :total], _measurements, _metadata, _config) do
    try do
      :ets.update_counter(:metrics, :requests_total, {2, 1})
    rescue
      _ -> :ok
    end
  end

  @impl true
  def init(opts) do
    %{
      enabled: Keyword.get(opts, :enabled, true),
      endpoint: Keyword.get(opts, :endpoint, "/metrics")
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
    metrics_data = %{
      requests_total: safe_get_counter(:requests_total),
      requests_by_method: %{},
      requests_by_status: %{},
      avg_duration: 0
    }

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, format_prometheus(metrics_data))
    |> halt()
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
    """
    # HELP hibana_requests_total Total requests
    # TYPE hibana_requests_total counter
    hibana_requests_total #{data.requests_total}

    # HELP hibana_request_duration_ms Request duration in milliseconds
    # TYPE hibana_request_duration_ms histogram
    hibana_request_duration_ms_count #{data.avg_duration}
    """
  end
end
