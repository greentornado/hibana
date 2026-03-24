defmodule Hibana.Cron do
  @moduledoc """
  Built-in cron scheduler. Schedule recurring jobs with cron expressions.

  ## Usage

      defmodule MyApp.Scheduler do
        use Hibana.Cron

        schedule "*/5 * * * *", MyApp.CleanupJob        # Every 5 minutes
        schedule "0 * * * *", MyApp.HourlyReport         # Every hour
        schedule "0 0 * * *", MyApp.DailyDigest           # Daily at midnight
        schedule "0 0 * * 1", MyApp.WeeklyReport          # Monday at midnight
      end

      # Add to supervision tree
      children = [MyApp.Scheduler]

  ## Cron Expression Format

      minute (0-59)
      hour (0-23)
      day of month (1-31)
      month (1-12)
      day of week (0-6, 0=Sunday)

      * * * * *

  Supports: `*`, `*/N`, `N`, `N-M`, `N,M,O`
  """

  defmacro __using__(_opts) do
    quote do
      import Hibana.Cron, only: [schedule: 2]
      Module.register_attribute(__MODULE__, :schedules, accumulate: true)
      @before_compile Hibana.Cron
    end
  end

  defmacro schedule(expression, module) do
    quote do
      @schedules {unquote(expression), unquote(module)}
    end
  end

  defmacro __before_compile__(env) do
    schedules = Module.get_attribute(env.module, :schedules) |> Enum.reverse()

    quote do
      require Logger
      use GenServer

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      def init(_opts) do
        schedules = unquote(Macro.escape(schedules))
        schedule_next_tick()
        {:ok, %{schedules: schedules}}
      end

      def handle_info(:tick, state) do
        now = NaiveDateTime.utc_now()
        minute = now.minute
        hour = now.hour
        day = now.day
        month = now.month
        weekday = Date.day_of_week(NaiveDateTime.to_date(now)) |> rem(7)

        Enum.each(state.schedules, fn {expression, module} ->
          if Hibana.Cron.matches?(expression, minute, hour, day, month, weekday) do
            Task.start(fn ->
              try do
                module.perform(%{})
              rescue
                e -> Logger.warning("[Cron] Error running #{inspect(module)}: #{inspect(e)}")
              end
            end)
          end
        end)

        schedule_next_tick()
        {:noreply, state}
      end

      defp schedule_next_tick do
        # Calculate ms until next minute boundary
        now = System.system_time(:millisecond)
        next_minute = div(now, 60_000) * 60_000 + 60_000
        delay = next_minute - now
        Process.send_after(self(), :tick, delay)
      end

      def child_spec(opts) do
        %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}, type: :worker}
      end
    end
  end

  @doc """
  Checks if a cron expression matches the given time components.

  ## Parameters

    - `expression` - A 5-field cron expression string (e.g., `"*/5 * * * *"`)
    - `minute` - Current minute (0-59)
    - `hour` - Current hour (0-23)
    - `day` - Current day of month (1-31)
    - `month` - Current month (1-12)
    - `weekday` - Current day of week (0-6, 0=Sunday)

  ## Returns

  `true` if the expression matches, `false` otherwise.

  ## Supported Syntax

  - `*` - Match all values
  - `*/N` - Match every N-th value
  - `N` - Match exact value
  - `N-M` - Match range
  - `N,M,O` - Match list of values

  ## Examples

      ```elixir
      Hibana.Cron.matches?("*/5 * * * *", 10, 14, 1, 1, 3)
      # => true (minute 10 is divisible by 5)

      Hibana.Cron.matches?("0 0 * * *", 0, 0, 15, 6, 2)
      # => true (midnight)
      ```
  """
  def matches?(expression, minute, hour, day, month, weekday) do
    parts = String.split(expression, " ")

    case parts do
      [m, h, d, mo, w] ->
        field_matches?(m, minute, 0, 59) and
          field_matches?(h, hour, 0, 23) and
          field_matches?(d, day, 1, 31) and
          field_matches?(mo, month, 1, 12) and
          field_matches?(w, weekday, 0, 6)

      _ ->
        false
    end
  end

  defp field_matches?("*", _value, _min, _max), do: true

  defp field_matches?("*/" <> step_str, value, min, _max) do
    step = String.to_integer(step_str)
    rem(value - min, step) == 0
  end

  defp field_matches?(spec, value, _min, _max) do
    spec
    |> String.split(",")
    |> Enum.any?(fn part ->
      case String.split(part, "-") do
        [single] -> String.to_integer(single) == value
        [from, to] -> value >= String.to_integer(from) and value <= String.to_integer(to)
      end
    end)
  end
end
