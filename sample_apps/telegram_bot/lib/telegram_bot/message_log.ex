defmodule TelegramBot.MessageLog do
  @moduledoc """
  ETS-based message log for storing recent Telegram updates for debugging.
  Keeps the last 100 messages.
  """

  @table :telegram_messages
  @max_messages 100

  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:ordered_set, :public, :named_table])
    end

    :ok
  end

  def log(update) do
    timestamp = System.system_time(:microsecond)

    entry = %{
      timestamp: DateTime.utc_now() |> DateTime.to_string(),
      update_id: update["update_id"],
      type: detect_type(update),
      from: extract_from(update),
      text: extract_text(update),
      raw: update
    }

    :ets.insert(@table, {timestamp, entry})
    trim()
    :ok
  end

  def recent(limit \\ 20) do
    @table
    |> :ets.tab2list()
    |> Enum.sort_by(fn {ts, _} -> ts end, :desc)
    |> Enum.take(limit)
    |> Enum.map(fn {_ts, entry} -> entry end)
  end

  def count do
    :ets.info(@table, :size)
  end

  def clear do
    :ets.delete_all_objects(@table)
    :ok
  end

  defp trim do
    size = :ets.info(@table, :size)

    if size > @max_messages do
      to_remove = size - @max_messages

      @table
      |> :ets.tab2list()
      |> Enum.sort_by(fn {ts, _} -> ts end, :asc)
      |> Enum.take(to_remove)
      |> Enum.each(fn {ts, _} -> :ets.delete(@table, ts) end)
    end
  end

  defp detect_type(update) do
    cond do
      update["message"] -> "message"
      update["callback_query"] -> "callback_query"
      update["edited_message"] -> "edited_message"
      update["channel_post"] -> "channel_post"
      true -> "unknown"
    end
  end

  defp extract_from(update) do
    cond do
      update["message"] ->
        get_in(update, ["message", "from", "first_name"]) || "unknown"

      update["callback_query"] ->
        get_in(update, ["callback_query", "from", "first_name"]) || "unknown"

      true ->
        "unknown"
    end
  end

  defp extract_text(update) do
    cond do
      update["message"] -> get_in(update, ["message", "text"])
      update["callback_query"] -> get_in(update, ["callback_query", "data"])
      true -> nil
    end
  end
end
