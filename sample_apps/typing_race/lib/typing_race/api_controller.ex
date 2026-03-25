defmodule TypingRace.ApiController do
  use Hibana.Controller

  def create(conn) do
    max_players =
      case conn.body_params do
        %{"max_players" => n} when is_integer(n) and n >= 2 and n <= 8 -> n
        _ -> 4
      end

    case TypingRace.RaceManager.create_race(max_players) do
      {:ok, code} ->
        put_status(conn, 201) |> json(%{code: code, max_players: max_players})

      {:error, reason} ->
        put_status(conn, 500) |> json(%{error: inspect(reason)})
    end
  end

  def join(conn) do
    code = conn.params["code"]
    name = Map.get(conn.body_params, "name", "")

    cond do
      name == "" ->
        put_status(conn, 400) |> json(%{error: "Name is required"})

      !TypingRace.RaceManager.race_exists?(code) ->
        put_status(conn, 404) |> json(%{error: "Race not found"})

      true ->
        case TypingRace.RaceServer.join(code, name) do
          {:ok, _state} ->
            json(conn, %{ok: true, code: code, name: name})

          {:error, reason} ->
            put_status(conn, 400) |> json(%{error: reason})
        end
    end
  end

  def show(conn) do
    code = conn.params["code"]

    if TypingRace.RaceManager.race_exists?(code) do
      case TypingRace.RaceServer.get_state(code) do
        {:ok, state} -> json(conn, state)
        _ -> put_status(conn, 500) |> json(%{error: "Failed to get race state"})
      end
    else
      put_status(conn, 404) |> json(%{error: "Race not found"})
    end
  end

  def health(conn) do
    json(conn, %{status: "ok", app: "typing_race"})
  end

  def websocket(conn) do
    Hibana.WebSocket.upgrade(conn, TypingRace.RaceSocket)
  end
end
