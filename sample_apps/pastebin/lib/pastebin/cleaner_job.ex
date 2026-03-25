defmodule Pastebin.CleanerJob do
  def perform(_) do
    Pastebin.Store.cleanup_expired()
  end
end
