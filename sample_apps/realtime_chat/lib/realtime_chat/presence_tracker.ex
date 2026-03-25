defmodule RealtimeChat.PresenceTracker do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    {:ok, %{rooms: %{}, monitors: %{}}}
  end

  @doc "Track a user joining a room"
  def join(room_id, username, pid) do
    GenServer.call(__MODULE__, {:join, room_id, username, pid})
  end

  @doc "Track a user leaving a room"
  def leave(room_id, username, pid) do
    GenServer.call(__MODULE__, {:leave, room_id, username, pid})
  end

  @doc "Remove a user from all rooms (on disconnect)"
  def remove_user(pid) do
    GenServer.call(__MODULE__, {:remove_user, pid})
  end

  @doc "Get users in a room"
  def get_users(room_id) do
    GenServer.call(__MODULE__, {:get_users, room_id})
  end

  @doc "Broadcast a message to all users in a room"
  def broadcast(room_id, message) do
    GenServer.cast(__MODULE__, {:broadcast, room_id, message})
  end

  # Server callbacks

  def handle_call({:join, room_id, username, pid}, _from, state) do
    # Monitor the process
    ref = Process.monitor(pid)
    monitors = Map.put(state.monitors, ref, {room_id, username, pid})

    # Add user to room
    room_users = Map.get(state.rooms, room_id, [])
    entry = %{username: username, pid: pid}

    # Avoid duplicates
    room_users =
      room_users
      |> Enum.reject(fn u -> u.pid == pid and u.username == username end)
      |> Kernel.++([entry])

    rooms = Map.put(state.rooms, room_id, room_users)

    # Broadcast join to all users in the room
    broadcast_to_room(rooms, room_id, %{
      type: "user_joined",
      room: room_id,
      user: username
    })

    # Send presence list to all users in the room
    broadcast_presence(rooms, room_id)

    {:reply, :ok, %{state | rooms: rooms, monitors: monitors}}
  end

  def handle_call({:leave, room_id, username, pid}, _from, state) do
    {rooms, monitors} = do_leave(state.rooms, state.monitors, room_id, username, pid)
    {:reply, :ok, %{state | rooms: rooms, monitors: monitors}}
  end

  def handle_call({:remove_user, pid}, _from, state) do
    {rooms, monitors} = do_remove_user(state.rooms, state.monitors, pid)
    {:reply, :ok, %{state | rooms: rooms, monitors: monitors}}
  end

  def handle_call({:get_users, room_id}, _from, state) do
    users =
      Map.get(state.rooms, room_id, [])
      |> Enum.map(& &1.username)
      |> Enum.uniq()

    {:reply, users, state}
  end

  def handle_cast({:broadcast, room_id, message}, state) do
    broadcast_to_room(state.rooms, room_id, message)
    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, pid, _reason}, state) do
    {rooms, monitors} = do_remove_user(state.rooms, state.monitors, pid)
    monitors = Map.delete(monitors, ref)
    {:noreply, %{state | rooms: rooms, monitors: monitors}}
  end

  # Private helpers

  defp do_leave(rooms, monitors, room_id, username, pid) do
    room_users = Map.get(rooms, room_id, [])
    updated = Enum.reject(room_users, fn u -> u.pid == pid and u.username == username end)
    rooms = Map.put(rooms, room_id, updated)

    # Remove associated monitors
    monitors =
      monitors
      |> Enum.reject(fn {_ref, {r, u, p}} -> r == room_id and u == username and p == pid end)
      |> Map.new()

    # Broadcast leave
    broadcast_to_room(rooms, room_id, %{
      type: "user_left",
      room: room_id,
      user: username
    })

    broadcast_presence(rooms, room_id)

    {rooms, monitors}
  end

  defp do_remove_user(rooms, monitors, pid) do
    # Find all rooms this pid is in
    affected =
      monitors
      |> Enum.filter(fn {_ref, {_room, _user, p}} -> p == pid end)
      |> Enum.map(fn {ref, {room_id, username, _p}} -> {ref, room_id, username} end)

    # Remove from all rooms
    rooms =
      Enum.reduce(affected, rooms, fn {_ref, room_id, _username}, acc ->
        room_users = Map.get(acc, room_id, [])
        updated = Enum.reject(room_users, fn u -> u.pid == pid end)
        Map.put(acc, room_id, updated)
      end)

    # Remove monitors
    refs_to_remove = Enum.map(affected, fn {ref, _, _} -> ref end)
    monitors = Map.drop(monitors, refs_to_remove)

    # Broadcast leaves
    Enum.each(affected, fn {_ref, room_id, username} ->
      broadcast_to_room(rooms, room_id, %{
        type: "user_left",
        room: room_id,
        user: username
      })

      broadcast_presence(rooms, room_id)
    end)

    {rooms, monitors}
  end

  defp broadcast_to_room(rooms, room_id, message) do
    room_users = Map.get(rooms, room_id, [])

    Enum.each(room_users, fn %{pid: pid} ->
      send(pid, {:broadcast, message})
    end)
  end

  defp broadcast_presence(rooms, room_id) do
    room_users = Map.get(rooms, room_id, [])
    usernames = room_users |> Enum.map(& &1.username) |> Enum.uniq()

    message = %{
      type: "presence",
      room: room_id,
      users: usernames
    }

    Enum.each(room_users, fn %{pid: pid} ->
      send(pid, {:broadcast, message})
    end)
  end
end
