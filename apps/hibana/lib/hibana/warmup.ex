defmodule Hibana.Warmup do
  @moduledoc """
  Pre-load data on startup with a macro DSL.

  ## Usage

      defmodule MyApp.Warmup do
        use Hibana.Warmup

        warmup "load config" do
          Application.fetch_env!(:my_app, :config)
        end

        warmup "prime cache" do
          MyApp.Cache.prime()
        end
      end

  Then add to your supervision tree:

      children = [
        MyApp.Warmup
      ]

  The module runs all warmup tasks sequentially on `start_link/1` and
  returns `:ignore` so it acts as a temporary worker.
  """

  defmacro __using__(_opts) do
    quote do
      Module.register_attribute(__MODULE__, :warmup_tasks, accumulate: true)
      @before_compile Hibana.Warmup
      import Hibana.Warmup, only: [warmup: 2]
    end
  end

  @doc """
  Define a warmup task with a name and body.
  """
  defmacro warmup(name, do: body) do
    func_name = :"warmup_#{:erlang.phash2(name)}"

    quote do
      @warmup_tasks {unquote(name), unquote(func_name)}

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

        Enum.each(tasks, fn {name, func_name} ->
          start = System.monotonic_time(:microsecond)

          try do
            apply(__MODULE__, func_name, [])
            elapsed = System.monotonic_time(:microsecond) - start
            Logger.info("[Warmup] #{name} completed in #{format_time(elapsed)}")
          rescue
            e ->
              elapsed = System.monotonic_time(:microsecond) - start
              Logger.warning("[Warmup] #{name} failed in #{format_time(elapsed)} - #{inspect(e)}")
          end
        end)

        Logger.info("[Warmup] Complete.")

        :ignore
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
