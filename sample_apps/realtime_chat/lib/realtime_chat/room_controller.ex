defmodule RealtimeChat.RoomController do
  use Hibana.Controller

  alias RealtimeChat.{RoomRegistry, MessageStore, PresenceTracker}

  def index(conn) do
    rooms = RoomRegistry.list_rooms()

    rooms_with_users =
      Enum.map(rooms, fn room ->
        users = PresenceTracker.get_users(room.id)
        Map.put(room, :user_count, length(users))
      end)

    json(conn, %{rooms: rooms_with_users})
  end

  def create(conn) do
    name = conn.body_params["name"]

    if is_nil(name) or String.trim(name) == "" do
      conn |> put_status(400) |> json(%{error: "Room name is required"})
    else
      case RoomRegistry.create_room(String.trim(name)) do
        {:ok, room} ->
          conn |> put_status(201) |> json(%{room: room})

        {:error, :already_exists} ->
          conn |> put_status(409) |> json(%{error: "Room already exists"})
      end
    end
  end

  def messages(conn) do
    room_id = conn.params["id"]

    case RoomRegistry.get_room(room_id) do
      {:ok, _room} ->
        messages = MessageStore.get_messages(room_id)
        json(conn, %{room: room_id, messages: messages})

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "Room not found"})
    end
  end
end
