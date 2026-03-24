defmodule Hibana.CodeReloader do
  @moduledoc """
  Hot code reloading for development. Watches source files and automatically
  recompiles when changes are detected.

  ## Usage

      # Add to your supervision tree (dev only)
      if Mix.env() == :dev do
        children = [
          {Hibana.CodeReloader, dirs: ["lib"], interval: 1_000}
        ]
      end

  ## Options
  - `:dirs` - Directories to watch (default: `["lib"]`)
  - `:interval` - Poll interval in ms (default: `1_000`)
  - `:callback` - Function called after recompile (default: `nil`)
  """

  use GenServer
  require Logger

  @doc """
  Starts the code reloader GenServer.

  ## Parameters

    - `opts` - Keyword list of options:
      - `:dirs` - Directories to watch for changes (default: `["lib"]`)
      - `:interval` - Poll interval in milliseconds (default: `1_000`)
      - `:callback` - Optional function called after successful recompile

  ## Returns

    - `{:ok, pid}` on success

  ## Examples

      ```elixir
      Hibana.CodeReloader.start_link(dirs: ["lib"], interval: 2_000)
      ```
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    dirs = Keyword.get(opts, :dirs, ["lib"])
    interval = Keyword.get(opts, :interval, 1_000)
    callback = Keyword.get(opts, :callback)

    state = %{
      dirs: dirs,
      interval: interval,
      callback: callback,
      file_mtimes: scan_files(dirs)
    }

    schedule_check(interval)
    Logger.info("[CodeReloader] Watching #{Enum.join(dirs, ", ")} for changes...")
    {:ok, state}
  end

  def handle_info(:check, state) do
    current_mtimes = scan_files(state.dirs)
    changed = detect_changes(state.file_mtimes, current_mtimes)

    state =
      if changed != [] do
        Logger.info(
          "[CodeReloader] Changes detected in #{length(changed)} file(s): #{Enum.join(changed, ", ")}"
        )

        case recompile() do
          {:ok, _} ->
            Logger.info("[CodeReloader] Recompiled successfully")
            if state.callback, do: state.callback.()

          {:error, errors} ->
            Logger.error("[CodeReloader] Compilation errors: #{inspect(errors)}")
        end

        %{state | file_mtimes: current_mtimes}
      else
        state
      end

    schedule_check(state.interval)
    {:noreply, state}
  end

  defp scan_files(dirs) do
    dirs
    |> Enum.flat_map(fn dir ->
      Path.wildcard(Path.join(dir, "**/*.{ex,exs}"))
    end)
    |> Enum.into(%{}, fn file ->
      case File.stat(file) do
        {:ok, %{mtime: mtime}} -> {file, mtime}
        _ -> {file, nil}
      end
    end)
  end

  defp detect_changes(old_mtimes, new_mtimes) do
    new_mtimes
    |> Enum.filter(fn {file, mtime} ->
      old_mtime = Map.get(old_mtimes, file)
      old_mtime != mtime
    end)
    |> Enum.map(fn {file, _} -> file end)
  end

  defp recompile do
    try do
      IEx.Helpers.recompile()
      {:ok, :recompiled}
    rescue
      _ ->
        try do
          Mix.Task.reenable("compile.elixir")
          Mix.Task.run("compile.elixir", ["--ignore-module-conflict"])
          {:ok, :recompiled}
        rescue
          e -> {:error, e}
        end
    end
  end

  defp schedule_check(interval) do
    Process.send_after(self(), :check, interval)
  end

  def child_spec(opts) do
    %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}
  end
end
