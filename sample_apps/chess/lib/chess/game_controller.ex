defmodule Chess.GameController do
  use Hibana.Controller

  def create(conn) do
    case Chess.GameManager.create_game() do
      {:ok, game_id} ->
        {:ok, state} = Chess.GameServer.get_state(game_id)
        put_status(conn, 201) |> json(%{game: state, message: "Game created"})

      {:error, reason} ->
        put_status(conn, 500) |> json(%{error: "Failed to create game: #{inspect(reason)}"})
    end
  end

  def index(conn) do
    games = Chess.GameManager.list_games()
    json(conn, %{games: games, total: length(games)})
  end

  def show(conn) do
    id = conn.params["id"]

    if Chess.GameServer.alive?(id) do
      {:ok, state} = Chess.GameServer.get_state(id)
      json(conn, %{game: state})
    else
      put_status(conn, 404) |> json(%{error: "Game not found"})
    end
  end

  def move(conn) do
    id = conn.params["id"]
    body = conn.body_params
    from = Map.get(body, "from")
    to = Map.get(body, "to")

    cond do
      is_nil(from) or is_nil(to) ->
        put_status(conn, 400) |> json(%{error: "Missing 'from' and 'to' fields"})

      not Chess.GameServer.alive?(id) ->
        put_status(conn, 404) |> json(%{error: "Game not found"})

      true ->
        case Chess.GameServer.make_move(id, from, to) do
          {:ok, state} ->
            json(conn, %{game: state, message: "Move accepted"})

          {:error, reason} ->
            put_status(conn, 400) |> json(%{error: reason})
        end
    end
  end

  def websocket(conn) do
    id = conn.params["id"]

    if Chess.GameServer.alive?(id) do
      Hibana.WebSocket.upgrade(conn, Chess.GameSocket, %{game_id: id})
    else
      put_status(conn, 404) |> json(%{error: "Game not found"})
    end
  end
end
