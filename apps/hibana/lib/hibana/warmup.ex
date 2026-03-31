defmodule Hibana.Warmup do
  @moduledoc """
  Pre-load data on startup with a macro DSL and timeout protection.

  ## Usage

      defmodule MyApp.Warmup do
        use Hibana.Warmup

        warmup "load config", timeout: 5_000 do
          Application.fetch_env!(:my_app, :config)
        end

        warmup "prime cache", timeout: 10_000 do
          MyApp.Cache.prime()
        end

        warmup "connect to db", timeout: 30_000 do
          MyApp.Repo.query("SELECT 1")
        end
      end

  Then add to your supervision tree:

      children = [
        MyApp.Warmup
      ]

  The module runs all warmup tasks sequentially on `start_link/1` with
  individual timeouts. Returns `:ignore` so it acts as a temporary worker.

  ## Timeout Protection

  Each task can specify a timeout (default: 30 seconds). If a task exceeds
  its timeout, it is forcefully terminated and an error is logged, but
  startup continues with the remaining tasks.
  """

  @default_timeout 30_000

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :warmup_tasks, accumulate: true)
      @before_compile Hibana.Warmup
      import Hibana.Warmup, only: [warmup: 2]
    end
  end

  @doc """
  Define a warmup task with a name, options, and body.

  ## Options

    - `:timeout` - Maximum time in milliseconds to wait for the task
      (default: `30_000`)

  ## Examples

      warmup "load cache", timeout: 10_000 do
        Cache.warm()
      end
  """
  defmacro warmup(name, opts \\ [], do: body) do
    func_name = :"warmup_#{:erlang.phash2(name)}"
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    quote do
      @warmup_tasks {unquote(name), unquote(func_name), unquote(timeout)}

      def unquote(func_name)() do
        unquote(body)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def start_link(_opts \\ []) do
        tasks = @warmup_tasks |> Enum.reverse()

        require Logger
        Logger.info("[Warmup] Starting #{length(tasks)} warmup task(s)...")

        Enum.each(tasks, fn {name, func_name, timeout} ->
          run_task_with_timeout(__MODULE__, name, func_name, timeout)
        end)

        Logger.info("[Warmup] Complete.")

        :ignore
      end

      defp run_task_with_timeout(mod, name, func_name, timeout) do
        start = System.monotonic_time(:microsecond)

        require Logger
        Logger.info("[Warmup] Starting task '#{name}' (timeout: #{timeout}ms)...")

        # Use spawn_monitor to run task with timeout protection
        # This catches exceptions without crashing the parent
        {child_pid, child_ref} =
          spawn_monitor(fn ->
            try do
              result = apply(mod, func_name, [])
              {:ok, result}
            rescue
              e -> {:error, {:exception, e, __STACKTRACE__}}
            catch
              :exit, reason -> {:error, {:exit, reason}}
            end
          end)

        # Wait for the task with timeout
        result =
          receive do
            {:DOWN, ^child_ref, :process, ^child_pid, :normal} ->
              # This shouldn't happen since we send result before exiting
              elapsed = System.monotonic_time(:microsecond) - start
              Logger.info("[Warmup] #{name} completed in #{format_time(elapsed)}")
              :ok

            {:DOWN, ^child_ref, :process, ^child_pid, {:error, reason}} ->
              elapsed = System.monotonic_time(:microsecond) - start

              case reason do
                {:exception, e, _stack} ->
                  Logger.warning(
                    "[Warmup] #{name} raised exception after #{format_time(elapsed)} - #{inspect(e)}"
                  )

                {:exit, exit_reason} ->
                  Logger.warning(
                    "[Warmup] #{name} exited after #{format_time(elapsed)} - #{inspect(exit_reason)}"
                  )
              end

              :error
          after
            timeout ->
              # Task timed out - kill it
              elapsed = System.monotonic_time(:microsecond) - start
              Process.exit(child_pid, :kill)
              # Wait for the DOWN message to avoid leaking the monitor
              receive do
                {:DOWN, ^child_ref, :process, ^child_pid, _} -> :ok
              end

              Logger.error("[Warmup] #{name} timed out after #{timeout}ms (task was killed)")
              {:error, :timeout}
          end

        result
      end

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :temporary
        }
      end

      defp format_time(microseconds) when microseconds < 1_000 do
        "#{microseconds}µs"
      end

      defp format_time(microseconds) when microseconds < 1_000_000 do
        ms = Float.round(microseconds / 1_000, 1)
        "#{ms}ms"
      end

      defp format_time(microseconds) do
        s = Float.round(microseconds / 1_000_000, 2)
        "#{s}s"
      end
    end
  end
end
