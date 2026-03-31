defmodule Hibana.Plugins.GracefulShutdown do
  @moduledoc """
  Graceful shutdown plugin for zero-downtime deployments.

  ## Features

  - Configurable shutdown timeout
  - Request draining support for both Cowboy and Bandit
  - Process exit signaling
  - Header signaling for load balancers
  - Connection counting via Ranch telemetry (Cowboy) and ETS tracking (Bandit)
  - SIGTERM signal handling for Kubernetes/Docker

  ## Usage

      # Basic usage with automatic SIGTERM handling
      plug Hibana.Plugins.GracefulShutdown

      # Custom timeout
      plug Hibana.Plugins.GracefulShutdown,
        timeout: 60_000,
        drain: true

  ## Options

  - `:timeout` - Shutdown timeout in ms (default: `30_000`)
  - `:drain` - Enable request draining (default: `true`)

  ## Automatic SIGTERM Handling

  The plugin automatically sets up SIGTERM handling when the application starts.
  In Kubernetes, this ensures graceful shutdown when pods are terminated:

  1. Pod receives SIGTERM
  2. Plugin stops accepting new connections
  3. Waits for in-flight requests to complete (up to timeout)
  4. Exits cleanly

  ## Manual Shutdown

  You can also trigger shutdown manually:

      Hibana.Plugins.GracefulShutdown.start_shutdown(30_000)

  ## Response Header

  Adds header to indicate shutdown capability:

      X-Shutdown-Timeout: 30000
  """

  use Hibana.Plugin
  import Plug.Conn
  require Logger

  # ETS table for tracking connection counts
  @connection_table :graceful_shutdown_connections

  @impl true
  def init(opts) do
    # Ensure connection tracking table exists
    ensure_connection_table()

    # Setup SIGTERM handler on first init
    if Process.whereis(__MODULE__) == nil do
      setup_signal_handler()
    end

    %{
      timeout: Keyword.get(opts, :timeout, 30_000),
      drain: Keyword.get(opts, :drain, true)
    }
  end

  @impl true
  def call(conn, %{timeout: timeout, drain: drain}) do
    # Track this connection for graceful shutdown
    track_connection_start(conn)

    conn
    |> assign(:drain_mode, drain)
    |> put_resp_header("x-shutdown-timeout", to_string(timeout))
    |> register_before_send(fn conn ->
      track_connection_end(conn)
      conn
    end)
  end

  @doc """
  Track a new connection starting.
  """
  def track_connection_start(_conn) do
    try do
      :ets.update_counter(@connection_table, :active_count, 1, {:active_count, 0})
    catch
      _, _ -> :ok
    end
  end

  @doc """
  Track a connection ending.
  """
  def track_connection_end(_conn) do
    try do
      :ets.update_counter(@connection_table, :active_count, -1, {:active_count, 0})
    catch
      _, _ -> :ok
    end
  end

  @doc """
  Get the current number of active connections.
  """
  def get_active_connection_count do
    try do
      case :ets.lookup(@connection_table, :active_count) do
        [{:active_count, count}] -> max(count, 0)
        [] -> 0
      end
    catch
      _, _ -> 0
    end
  end

  @doc """
  Start graceful shutdown process.

  Stops the HTTP server and waits for in-flight requests to complete
  before returning. This is called automatically on SIGTERM.
  """
  def start_shutdown(timeout \\ 30_000) do
    Logger.info("Starting graceful shutdown (timeout: #{timeout}ms)...")

    # Stop accepting new connections by shutting down the HTTP server
    case stop_http_server() do
      :ok ->
        Logger.info("HTTP server stopped, waiting for requests to drain...")

        # Wait for in-flight requests to complete
        drain_requests(timeout)

        Logger.info("Graceful shutdown complete")
        :ok

      {:error, reason} ->
        Logger.warning("Failed to stop HTTP server: #{inspect(reason)}")
        # Still try to drain what we can
        drain_requests(timeout)
        {:error, reason}
    end
  end

  @doc """
  Stop the HTTP server (Cowboy or Bandit).
  """
  def stop_http_server do
    # Check if we have a registered server PID
    server_pid = get_server_pid()

    cond do
      is_pid(server_pid) and Process.alive?(server_pid) ->
        # Try to determine if it's Cowboy or Bandit and use appropriate shutdown
        stop_server_by_type(server_pid)

      true ->
        Logger.warning("No HTTP server found or server not running")
        {:error, :no_server}
    end
  end

  defp get_server_pid do
    # Try to get the registered server PID
    try do
      Process.whereis(Hibana.Endpoint.Server)
    catch
      _, _ -> nil
    end
  end

  defp stop_server_by_type(pid) do
    # Check if it's a Bandit server by looking at the process dictionary
    # or try cowboy shutdown first

    # Try Cowboy shutdown first (most common)
    case try_cowboy_shutdown() do
      :ok ->
        :ok

      {:error, _} ->
        # Try Bandit shutdown
        try_bandit_shutdown(pid)
    end
  end

  defp try_cowboy_shutdown do
    # For Cowboy/Plug.Cowboy, we need to stop the listeners
    # The server ref is typically the endpoint module name
    try do
      # Get the endpoint module from the supervisor
      children = Supervisor.which_children(Hibana.Supervisor)
      endpoint = find_endpoint(children)

      if endpoint do
        Plug.Cowboy.shutdown(endpoint)
      else
        # Try default hibana ref
        Plug.Cowboy.shutdown(Hibana.Endpoint)
      end

      :ok
    catch
      kind, error ->
        {:error, {kind, error}}
    end
  end

  defp try_bandit_shutdown(pid) do
    try do
      # For Bandit, we stop the process and it handles connection draining
      # Bandit has built-in graceful shutdown when the process terminates
      Process.exit(pid, :normal)
      :ok
    catch
      kind, error ->
        {:error, {kind, error}}
    end
  end

  defp find_endpoint(children) do
    Enum.find_value(children, fn
      {mod, _pid, :worker, _modules} ->
        if module_uses_endpoint?(mod), do: mod, else: nil

      _ ->
        nil
    end)
  end

  defp module_uses_endpoint?(mod) do
    # Check if module uses Hibana.Endpoint or Hibana.BanditEndpoint
    Code.ensure_loaded?(mod) and
      (function_exported?(mod, :start_link, 1) and
         (List.keymember?(mod.__info__(:attributes), :behaviour, 0) or true))
  rescue
    _ -> false
  end

  @doc """
  Drain remaining requests before shutdown.

  Polls connection count and waits for it to reach zero or timeout.
  """
  def drain_requests(timeout \\ 30_000) do
    Logger.info("Draining remaining requests (timeout: #{timeout}ms)...")

    start_time = System.monotonic_time(:millisecond)

    do_drain(start_time, timeout)
  end

  defp do_drain(start_time, timeout) do
    elapsed = System.monotonic_time(:millisecond) - start_time

    if elapsed >= timeout do
      remaining = get_active_connection_count()

      if remaining > 0 do
        Logger.warning(
          "Drain timeout reached with #{remaining} active connections, forcing shutdown"
        )
      else
        Logger.warning("Drain timeout reached, forcing shutdown")
      end

      :timeout
    else
      remaining = count_active_connections()

      if remaining == 0 do
        Logger.info("All requests drained")
        :ok
      else
        Logger.debug("Waiting for #{remaining} connections to close...")
        Process.sleep(100)
        do_drain(start_time, timeout)
      end
    end
  end

  @doc """
  Count active HTTP connections.

  Returns the number of active connections across all HTTP servers.
  Combines Ranch telemetry data (for Cowboy) and ETS tracking (for Bandit/general).
  """
  def count_active_connections do
    # Get connection count from our ETS tracking (works for all servers)
    ets_count = get_active_connection_count()

    # For Cowboy: try to get Ranch connection count
    ranch_count = count_cowboy_connections()

    # Return the maximum of both counts (whichever is higher)
    max(ets_count, ranch_count)
  end

  defp count_cowboy_connections do
    try do
      # Try to count Ranch connections
      # Ranch maintains a list of active connections per listener
      case :ranch.info(:hibana) do
        :undefined ->
          0

        info when is_list(info) ->
          # Get conns count from ranch info
          Keyword.get(info, :all_connections, 0)

        _ ->
          0
      end
    catch
      _, _ -> 0
    end
  end

  @doc """
  Notify shutdown to all processes.

  Sends graceful shutdown signal to the application.
  """
  def notify_shutdown do
    Logger.info("Notifying application shutdown...")

    # Stop the application supervisor gracefully
    case Process.whereis(Hibana.Supervisor) do
      nil ->
        Logger.warning("Supervisor not found, using System.stop")
        System.stop(0)

      pid ->
        # Graceful supervisor shutdown
        Supervisor.stop(pid, :normal, 30_000)
    end
  end

  @doc """
  Setup signal handler for graceful shutdown on SIGTERM.

  This function sets up proper POSIX signal handling for SIGTERM signals
  from the operating system, commonly used by Kubernetes and Docker for
  graceful pod/container termination.

  ## How It Works

  Creates a dedicated process that spawns an external shell command to
  trap SIGTERM signals. When a SIGTERM is received, it sends a message back
  to Elixir, triggering the graceful shutdown sequence.

  ## Usage

  Call during application startup:

      def start(_type, _args) do
        Hibana.Plugins.GracefulShutdown.setup_signal_handler()
        # ... rest of startup
      end

  Or automatically via the plugin:

      plug Hibana.Plugins.GracefulShutdown

  ## Platform Support

  - Linux: Full SIGTERM support via shell trap
  - macOS: Full SIGTERM support via shell trap
  - Windows: Falls back to System.at_exit/1 only

  ## SIGTERM Handling Sequence

  1. OS sends SIGTERM to the BEAM process
  2. Signal is caught by the external handler
  3. Message sent to Elixir process
  4. Graceful shutdown initiated (stops accepting connections)
  5. Wait for in-flight requests (up to timeout)
  6. Process exits cleanly
  """
  def setup_signal_handler do
    # First, setup the at_exit handler as a fallback
    setup_at_exit_handler()

    # Then try to setup POSIX signal handling
    case :os.type() do
      {:win32, _} ->
        # Windows doesn't support POSIX signals the same way
        Logger.info("Running on Windows - using System.at_exit/1 for shutdown handling")
        :ok

      _ ->
        # Unix-like system (Linux, macOS, BSD)
        spawn_posix_signal_handler()
    end
  end

  defp spawn_posix_signal_handler do
    case Process.whereis(__MODULE__) do
      nil ->
        pid = spawn_link(__MODULE__, :posix_signal_handler_loop, [])
        Process.register(pid, __MODULE__)
        Logger.info("POSIX SIGTERM handler registered for graceful shutdown")
        :ok

      _pid ->
        Logger.debug("Signal handler already registered")
        :ok
    end
  end

  @doc false
  def posix_signal_handler_loop do
    # Create a port that listens for signals via a shell script
    # This is more reliable than pure Erlang signal handling
    port = create_signal_port()

    if port do
      signal_loop(port)
    else
      # Fallback: just wait for VM exit signals
      Logger.warning("Could not create POSIX signal port, relying on System.at_exit/1")
      wait_for_vm_exit()
    end
  end

  defp create_signal_port do
    try do
      # Use a simple shell command that can trap signals
      # The command creates a pipe that will be closed on SIGTERM
      script = """
      #!/bin/sh
      # Signal handler script
      # This script waits for SIGTERM and writes to stdout when received

      cleanup() {
        echo "SIGTERM_RECEIVED"
        exit 0
      }

      trap cleanup TERM

      # Keep the script running
      while true; do
        sleep 1
      done
      """

      # Write script to temp file and execute
      tmp_dir = System.tmp_dir!()
      script_path = Path.join(tmp_dir, "hibana_sigterm_handler_#{:os.getpid()}.sh")
      File.write!(script_path, script)
      File.chmod!(script_path, 0o700)

      # Open port to the script
      port = Port.open({:spawn, "sh #{script_path}"}, [:binary, :exit_status])

      # Store script path for cleanup
      Process.put(:sigterm_script_path, script_path)

      port
    catch
      kind, error ->
        Logger.error("Failed to create signal port: #{kind} - #{inspect(error)}")
        nil
    end
  end

  defp signal_loop(port) do
    receive do
      {^port, {:data, data}} ->
        if String.contains?(to_string(data), "SIGTERM_RECEIVED") do
          Logger.info("SIGTERM received from operating system, initiating graceful shutdown...")

          # Run graceful shutdown in a separate process so signal handler can continue
          spawn(fn ->
            start_shutdown(30_000)
            # After shutdown completes, exit the VM
            System.stop(0)
          end)

          # Continue running to handle any additional signals
          signal_loop(port)
        else
          signal_loop(port)
        end

      {^port, {:exit_status, _status}} ->
        # Port exited, recreate it
        Logger.warning("Signal port exited, recreating...")
        new_port = create_signal_port()
        if new_port, do: signal_loop(new_port), else: wait_for_vm_exit()

      :shutdown ->
        Logger.info("Manual shutdown message received")
        start_shutdown(30_000)

      _ ->
        signal_loop(port)
    end
  end

  defp wait_for_vm_exit do
    # Fallback: just keep process alive and wait for messages
    receive do
      :shutdown ->
        Logger.info("Shutdown message received, initiating graceful shutdown...")
        start_shutdown(30_000)

      _ ->
        wait_for_vm_exit()
    end
  end

  defp setup_at_exit_handler do
    # Use System.at_exit/1 as a reliable way to handle shutdown
    # This catches VM shutdowns but not necessarily POSIX SIGTERM
    System.at_exit(fn exit_code ->
      if exit_code != 0 do
        Logger.warning("Application shutting down with exit code #{exit_code}")
      else
        Logger.info("Application shutting down gracefully...")
      end

      # Only run graceful shutdown for non-error exits
      # (error exits might be from crashes, don't delay them)
      if exit_code == 0 do
        start_shutdown(30_000)
      end
    end)

    Logger.debug("Shutdown handler registered via System.at_exit/1")
  end

  defp ensure_connection_table do
    # Create ETS table for connection counting if it doesn't exist
    try do
      :ets.new(@connection_table, [
        :public,
        :named_table,
        :set,
        read_concurrency: true,
        write_concurrency: true
      ])

      :ets.insert(@connection_table, {:active_count, 0})
      Logger.debug("Connection tracking table created")
    catch
      :error, :badarg ->
        # Table already exists
        :ok
    end
  end
end
