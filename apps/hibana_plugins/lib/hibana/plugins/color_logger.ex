defmodule Hibana.Plugins.ColorLogger do
  @moduledoc """
  Pretty-printed colored request logger with timing breakdown.

  ## Usage

      plug Hibana.Plugins.ColorLogger

  ## Output Example

      | GET /api/users
      | Status: 200 OK
      | Duration: 12.4ms
      | Params: %{"page" => "1"}
      +-----------------------

  ## Options

  - `:level` - Logger level to use for output (default: `:info`)
  - `:include_params` - Whether to log request parameters (default: `true`)
  - `:include_headers` - Whether to log request headers (default: `false`)
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  @impl true
  def init(opts) do
    %{
      level: Keyword.get(opts, :level, :info),
      include_params: Keyword.get(opts, :include_params, true),
      include_headers: Keyword.get(opts, :include_headers, false)
    }
  end

  @impl true
  def call(conn, opts) do
    start = System.monotonic_time(:microsecond)

    register_before_send(conn, fn conn ->
      duration = System.monotonic_time(:microsecond) - start
      log_request(conn, duration, opts)
      conn
    end)
  end

  defp log_request(conn, duration_us, opts) do
    status = conn.status
    method = conn.method
    path = conn.request_path
    duration = format_duration(duration_us)

    method_color = method_color(method)
    status_color = status_color(status)
    status_text = status_text(status)

    lines = [
      "\e[90m|\e[0m #{method_color}#{method}\e[0m #{path}",
      "\e[90m|\e[0m Status: #{status_color}#{status} #{status_text}\e[0m",
      "\e[90m|\e[0m Duration: \e[33m#{duration}\e[0m"
    ]

    lines =
      if opts.include_params and map_size(conn.params || %{}) > 0 do
        lines ++ ["\e[90m|\e[0m Params: #{inspect(conn.params)}"]
      else
        lines
      end

    lines = lines ++ ["\e[90m+---------------------\e[0m"]

    message = Enum.join(lines, "\n")
    Logger.log(opts.level, message)
  end

  defp format_duration(us) when us < 1_000, do: "#{us}us"
  defp format_duration(us) when us < 1_000_000, do: "#{Float.round(us / 1_000, 1)}ms"
  defp format_duration(us), do: "#{Float.round(us / 1_000_000, 2)}s"

  defp method_color("GET"), do: "\e[32m"
  defp method_color("POST"), do: "\e[34m"
  defp method_color("PUT"), do: "\e[33m"
  defp method_color("PATCH"), do: "\e[33m"
  defp method_color("DELETE"), do: "\e[31m"
  defp method_color(_), do: "\e[37m"

  defp status_color(s) when s >= 200 and s < 300, do: "\e[32m"
  defp status_color(s) when s >= 300 and s < 400, do: "\e[36m"
  defp status_color(s) when s >= 400 and s < 500, do: "\e[33m"
  defp status_color(s) when s >= 500, do: "\e[31m"
  defp status_color(_), do: "\e[37m"

  defp status_text(200), do: "OK"
  defp status_text(201), do: "Created"
  defp status_text(204), do: "No Content"
  defp status_text(301), do: "Moved"
  defp status_text(302), do: "Found"
  defp status_text(304), do: "Not Modified"
  defp status_text(400), do: "Bad Request"
  defp status_text(401), do: "Unauthorized"
  defp status_text(403), do: "Forbidden"
  defp status_text(404), do: "Not Found"
  defp status_text(422), do: "Unprocessable"
  defp status_text(429), do: "Too Many Requests"
  defp status_text(500), do: "Internal Error"
  defp status_text(502), do: "Bad Gateway"
  defp status_text(503), do: "Unavailable"
  defp status_text(_), do: ""
end
