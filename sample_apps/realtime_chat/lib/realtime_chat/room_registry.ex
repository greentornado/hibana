defmodule RealtimeChat.RoomRegistry do
  use GenServer

  @table :chat_rooms

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    table = :ets.new(@table, [:set, :public, :named_table, read_concurrency: true])

    # Seed data: create default rooms
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    :ets.insert(@table, {"general", %{id: "general", name: "General", created_at: now}})
    :ets.insert(@table, {"random", %{id: "random", name: "Random", created_at: now}})

    {:ok, %{table: table}}
  end

  @doc "List all rooms"
  def list_rooms do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, room} -> room end)
    |> Enum.sort_by(& &1.created_at)
  end

  @doc "Get a room by ID"
  def get_room(room_id) do
    case :ets.lookup(@table, room_id) do
      [{_id, room}] -> {:ok, room}
      [] -> {:error, :not_found}
    end
  end

  @doc "Create a new room"
  def create_room(name) do
    id = name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")

    case :ets.lookup(@table, id) do
      [{_id, _room}] ->
        {:error, :already_exists}

      [] ->
        now = DateTime.utc_now() |> DateTime.to_iso8601()
        room = %{id: id, name: name, created_at: now}
        :ets.insert(@table, {id, room})
        {:ok, room}
    end
  end
end
