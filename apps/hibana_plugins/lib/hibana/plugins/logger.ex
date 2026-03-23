defmodule Hibana.Plugins.Logger do
  @moduledoc """
  Request/Response logger plugin.

  ## Features

  - Request timing (start to finish)
  - Status code-based log levels
  - Configurable log level
  - Color-coded output support

  ## Usage

      # Basic usage
      plug Hibana.Plugins.Logger

      # With custom log level
      plug Hibana.Plugins.Logger, log_level: :debug

  ## Log Format

      [GET] /users 200 (45ms)
      [POST] /users 201 (120ms)
      [GET] /users/abc 404 (12ms)
      [GET] /api/users 500 (2345ms)

  ## Log Levels by Status Code

  - **200-399**: `:info` level
  - **400-499**: `:warning` level (client errors)
  - **500+**: `:error` level (server errors)

  ## Options

  - `:log_level` - Minimum log level (default: `:info`)

  ## Example Output

      [info]  [GET] /api/users 200 (45ms)
      [warn]  [GET] /api/users/invalid 404 (12ms)
      [error] [POST] /api/users 500 (2345ms)
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  @impl true
  def init(opts) do
    %{
      log_level: Keyword.get(opts, :log_level, :info)
    }
  end

  @impl true
  def call(conn, %{log_level: _level}) do
    start_time = System.monotonic_time(:millisecond)

    conn
    |> assign(:request_start_time, start_time)
  end

  @impl true
  def before_send(conn, %{log_level: _level}) do
    start_time = Map.get(conn.assigns, :request_start_time, nil)

    if start_time do
      elapsed = System.monotonic_time(:millisecond) - start_time
      status = conn.status
      method = conn.method
      path = conn.request_path

      message = "[#{method}] #{path} #{status} (#{elapsed}ms)"

      case status do
        n when n >= 500 -> Logger.error(message)
        n when n >= 400 -> Logger.warning(message)
        _ -> Logger.info(message)
      end
    end

    conn
  end
end
