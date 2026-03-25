defmodule RealtimeChat.MessageStore do
  use GenServer

  @table :chat_messages
  @max_messages 100

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])
    {:ok, %{}}
  end

  @doc "Store a message in a room (keeps last 100)"
  def add_message(room_id, user, text) do
    message = %{
      id: generate_id(),
      user: user,
      text: text,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    messages =
      case :ets.lookup(@table, room_id) do
        [{_id, existing}] -> existing
        [] -> []
      end

    updated = Enum.take(messages ++ [message], -@max_messages)
    :ets.insert(@table, {room_id, updated})
    message
  end

  @doc "Get messages for a room"
  def get_messages(room_id) do
    case :ets.lookup(@table, room_id) do
      [{_id, messages}] -> messages
      [] -> []
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
