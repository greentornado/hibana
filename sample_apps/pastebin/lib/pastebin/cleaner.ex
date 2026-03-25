defmodule Pastebin.Cleaner do
  use Hibana.Cron

  schedule "*/5 * * * *", Pastebin.CleanerJob
end
