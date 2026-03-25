defmodule RealtimeChat.ChatSocket do
  use Hibana.WebSocket

  alias RealtimeChat.{PresenceTracker, MessageStore, RoomRegistry}

  def init(conn, _opts) do
    # Extract username from query params
    query = conn.query_string || ""
    params = URI.decode_query(query)
    username = Map.get(params, "username", "anonymous")

    {:ok, conn, %{username: username, rooms: MapSet.new()}}
  end

  def handle_connect(_info, state) do
    {:ok, state}
  end

  def handle_disconnect(_reason, state) do
    # Remove from all rooms on disconnect
    PresenceTracker.remove_user(self())
    {:ok, state}
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, payload} ->
        handle_payload(payload, state)

      {:error, _} ->
        error = Jason.encode!(%{type: "error", message: "Invalid JSON"})
        {:reply, {:text, error}, state}
    end
  end

  def handle_info({:broadcast, message}, state) do
    {:push, {:text, Jason.encode!(message)}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end

  # Private handlers

  defp handle_payload(%{"type" => "join_room", "room" => room_id}, state) do
    case RoomRegistry.get_room(room_id) do
      {:ok, _room} ->
        PresenceTracker.join(room_id, state.username, self())
        rooms = MapSet.put(state.rooms, room_id)
        new_state = %{state | rooms: rooms}

        # Send message history
        messages = MessageStore.get_messages(room_id)

        history =
          Jason.encode!(%{
            type: "history",
            room: room_id,
            messages: messages
          })

        {:reply, {:text, history}, new_state}

      {:error, :not_found} ->
        error = Jason.encode!(%{type: "error", message: "Room not found: #{room_id}"})
        {:reply, {:text, error}, state}
    end
  end

  defp handle_payload(%{"type" => "leave_room", "room" => room_id}, state) do
    PresenceTracker.leave(room_id, state.username, self())
    rooms = MapSet.delete(state.rooms, room_id)
    new_state = %{state | rooms: rooms}

    confirm = Jason.encode!(%{type: "left_room", room: room_id})
    {:reply, {:text, confirm}, new_state}
  end

  defp handle_payload(%{"type" => "message", "room" => room_id, "text" => text}, state) do
    if MapSet.member?(state.rooms, room_id) do
      # Store the message
      message = MessageStore.add_message(room_id, state.username, text)

      # Broadcast to all users in the room via PresenceTracker
      broadcast = %{
        type: "message",
        room: room_id,
        user: state.username,
        text: text,
        timestamp: message.timestamp
      }

      PresenceTracker.broadcast(room_id, broadcast)

      {:ok, state}
    else
      error = Jason.encode!(%{type: "error", message: "Not in room: #{room_id}"})
      {:reply, {:text, error}, state}
    end
  end

  defp handle_payload(_payload, state) do
    error = Jason.encode!(%{type: "error", message: "Unknown message type"})
    {:reply, {:text, error}, state}
  end

  # Controller-style action for the router to call upgrade
  def upgrade(conn) do
    Hibana.WebSocket.upgrade(conn, __MODULE__)
  end
end
