# `Hibana.Cron`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/cron.ex#L1)

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

# `matches?`

Check if a cron expression matches the given time components

# `schedule`
*macro* 

---

*Consult [api-reference.md](api-reference.md) for complete listing*
