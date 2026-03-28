defmodule Hibana.Plugins.HealthCheck do
  @moduledoc """
  Health check endpoint plugin for load balancers and orchestration.

  ## Features

  - Built-in system health checks (memory, processes, uptime)
  - Custom health check registration
  - Prometheus-compatible response format
  - Configurable health endpoint path

  ## Usage

      # Basic usage (health endpoint at /health)
      plug Hibana.Plugins.HealthCheck

      # With custom path
      plug Hibana.Plugins.HealthCheck, path: "/api/health"

  ## Response Format

  Returns JSON:

      {
        "status": "healthy",
        "timestamp": 1234567890,
        "checks": {
          "memory": "ok",
          "processes": "ok",
          "uptime": "ok"
        }
      }

  - HTTP 200: All checks pass
  - HTTP 503: One or more checks fail

  ## Built-in Checks

  - **memory** - Checks if memory usage is below threshold
  - **processes** - Checks if process count is below threshold
  - **uptime** - Always returns :ok

  ## Custom Checks

  Register custom health checks:

      Hibana.Plugins.HealthCheck.register_check(:database, fn ->
        case DB.check_connection() do
          :ok -> :ok
          _ -> :error
        end
      end)

  ## Options

  - `:path` - Health endpoint path (default: `"/health"`)
  - `:checks` - List of additional checks to run

  ## Response Headers

  - `x-health-status` - "ok" or "error"
  - `content-type` - "application/json"
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      checks: Keyword.get(opts, :checks, []),
      path: Keyword.get(opts, :path, "/health"),
      custom_checks: %{}
    }
  end

  @impl true
  def call(conn, %{path: path}) do
    if conn.request_path == path do
      health_status(conn)
    else
      conn
    end
  end

  defp health_status(conn) do
    built_in = [
      {:memory, check_memory()},
      {:processes, check_processes()},
      {:uptime, check_uptime()}
    ]

    custom =
      Application.get_env(:hibana_plugins, :health_checks, %{})
      |> Enum.map(fn {name, fun} ->
        result =
          try do
            fun.()
          rescue
            _ -> :error
          end

        {name, result}
      end)

    checks = built_in ++ custom
    all_healthy = Enum.all?(checks, fn {_, status} -> status == :ok end)

    status_code = if all_healthy, do: 200, else: 503

    result = %{
      status: if(all_healthy, do: "healthy", else: "unhealthy"),
      timestamp: DateTime.utc_now() |> DateTime.to_unix(),
      checks: Enum.into(checks, %{}, fn {k, v} -> {k, v} end)
    }

    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("x-health-status", if(all_healthy, do: "ok", else: "error"))
    |> send_resp(status_code, Jason.encode!(result))
    |> halt()
  end

  defp check_memory do
    mem = :erlang.memory()
    total = Keyword.get(mem, :total, 0)

    max_memory =
      Application.get_env(:hibana_plugins, :health_check_memory_threshold, 2 * 1024 * 1024 * 1024)

    if total < max_memory, do: :ok, else: :warn
  end

  defp check_processes do
    count = length(Process.list())
    max_processes = Application.get_env(:hibana_plugins, :health_check_process_threshold, 100_000)
    if count < max_processes, do: :ok, else: :warn
  end

  defp check_uptime do
    :ok
  end

  @doc """
  Register a custom health check.
  """
  def register_check(name, fun) do
    existing = Application.get_env(:hibana_plugins, :health_checks, %{})
    Application.put_env(:hibana_plugins, :health_checks, Map.put(existing, name, fun))
  end
end
