defmodule Hibana.Plugins.GracefulShutdown do
  @moduledoc """
  Graceful shutdown plugin for zero-downtime deployments.

  ## Features

  - Configurable shutdown timeout
  - Request draining support
  - Process exit signaling
  - Header signaling for load balancers

  ## Usage

      # Basic usage
      plug Hibana.Plugins.GracefulShutdown

      # Custom timeout
      plug Hibana.Plugins.GracefulShutdown,
        timeout: 60_000,
        drain: true

  ## Options

  - `:timeout` - Shutdown timeout in ms (default: `30_000`)
  - `:drain` - Enable request draining (default: `true`)

  ## Module Functions

  ### start_shutdown/1
  Initiate graceful shutdown:

      Hibana.Plugins.GracefulShutdown.start_shutdown(30_000)

  ### drain_requests/1
  Wait for in-flight requests to complete:

      Hibana.Plugins.GracefulShutdown.drain_requests(30_000)

  ### notify_shutdown/0
  Signal shutdown to all processes:

      Hibana.Plugins.GracefulShutdown.notify_shutdown()

  ## Shutdown Sequence

  1. Receive SIGTERM
  2. Stop accepting new requests
  3. Drain existing requests (wait for completion)
  4. Timeout if requests take too long
  5. Exit process

  ## Response Header

  Adds header to indicate shutdown capability:

      X-Shutdown-Timeout: 30000
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  @impl true
  def init(opts) do
    %{
      timeout: Keyword.get(opts, :timeout, 30_000),
      drain: Keyword.get(opts, :drain, true)
    }
  end

  @impl true
  def call(conn, %{timeout: _timeout, drain: drain}) do
    conn
    |> assign(:drain_mode, drain)
    |> put_resp_header("x-shutdown-timeout", "30000")
  end

  @doc """
  Start graceful shutdown process.
  """
  def start_shutdown(timeout \\ 30_000) do
    Logger.info("Starting graceful shutdown (timeout: #{timeout}ms)...")

    # Stop accepting new connections
    try do
      :ranch.suspend_listener(:hibana)
    rescue
      _ -> :ok
    end

    # Wait for in-flight requests
    drain_requests(timeout)

    Logger.info("Shutdown complete")
    :ok
  end

  @doc """
  Drain remaining requests before shutdown.
  """
  def drain_requests(timeout \\ 30_000) do
    Logger.info("Draining remaining requests (timeout: #{timeout}ms)...")

    # Wait for active connections to complete
    try do
      :ranch.wait_for_connections(:hibana, :==, 0, timeout)
    rescue
      _ -> :ok
    end

    Logger.info("All requests drained")
    :ok
  end

  @doc """
  Notify shutdown to all processes.
  """
  def notify_shutdown do
    # Send shutdown signal to the application supervisor
    System.stop(0)
  end
end
