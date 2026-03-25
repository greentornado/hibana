defmodule TypingRace.RaceSocket do
  use Hibana.WebSocket

  def init(conn, _opts) do
    code = conn.params["code"]
    name = conn.params["name"]

    cond do
      is_nil(name) || name == "" ->
        {:halt, Plug.Conn.send_resp(conn, 400, "Missing name parameter")}

      !TypingRace.RaceManager.race_exists?(code) ->
        {:halt, Plug.Conn.send_resp(conn, 404, "Race not found")}

      true ->
        {:ok, conn, %{code: code, name: name, start_time: nil}}
    end
  end

  def handle_connect(_info, state) do
    TypingRace.RaceServer.register_socket(state.code, state.name, self())
    {:ok, state}
  end

  def handle_disconnect(_reason, state) do
    if state.code do
      TypingRace.RaceServer.unregister_socket(state.code, state.name)
    end

    {:ok, state}
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "start"}} ->
        case TypingRace.RaceServer.start_race(state.code) do
          :ok ->
            {:ok, state}

          {:error, reason} ->
            reply = Jason.encode!(%{type: "error", message: reason})
            {:reply, {:text, reply}, state}
        end

      {:ok, %{"type" => "progress", "typed" => typed, "position" => position}} ->
        TypingRace.RaceServer.update_progress(state.code, state.name, typed, position)
        {:ok, state}

      {:ok, %{"type" => "finished", "time_ms" => time_ms}} ->
        TypingRace.RaceServer.player_finished(state.code, state.name, time_ms)
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_info({:broadcast, encoded_message}, state) do
    {:push, {:text, encoded_message}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end
end
