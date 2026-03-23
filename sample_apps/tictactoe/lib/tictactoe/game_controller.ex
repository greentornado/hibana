defmodule TicTacToe.GameController do
  use Hibana.Controller

  def home(conn) do
    html_path = Path.join(:code.priv_dir(:tictactoe), "static/index.html")

    case File.read(html_path) do
      {:ok, content} ->
        html(conn, content)

      {:error, _} ->
        html(conn, "<h1>TicTacToe</h1><p>index.html not found in priv/static/</p>")
    end
  end

  def create(conn) do
    body = conn.body_params
    mode = Map.get(body, "mode", "pvp")

    unless mode in ["pvp", "ai"] do
      put_status(conn, 400) |> json(%{error: "Invalid mode. Use 'pvp' or 'ai'"})
    else
      game_id = generate_id()

      case DynamicSupervisor.start_child(
             TicTacToe.GameSupervisor,
             {TicTacToe.GameServer, {game_id, mode}}
           ) do
        {:ok, _pid} ->
          {:ok, state} = TicTacToe.GameServer.get_state(game_id)
          put_status(conn, 201) |> json(%{game: state, message: "Game created"})

        {:error, reason} ->
          put_status(conn, 500) |> json(%{error: "Failed to create game: #{inspect(reason)}"})
      end
    end
  end

  def show(conn) do
    id = conn.params["id"]

    if TicTacToe.GameServer.alive?(id) do
      {:ok, state} = TicTacToe.GameServer.get_state(id)
      json(conn, %{game: state})
    else
      put_status(conn, 404) |> json(%{error: "Game not found"})
    end
  end

  def move(conn) do
    id = conn.params["id"]
    body = conn.body_params
    position = Map.get(body, "position")
    player = Map.get(body, "player")

    cond do
      is_nil(position) or is_nil(player) ->
        put_status(conn, 400) |> json(%{error: "Missing 'position' and 'player' fields"})

      not TicTacToe.GameServer.alive?(id) ->
        put_status(conn, 404) |> json(%{error: "Game not found"})

      true ->
        pos = if is_binary(position), do: String.to_integer(position), else: position

        case TicTacToe.GameServer.make_move(id, pos, player) do
          {:ok, state} ->
            json(conn, %{game: state, message: "Move accepted"})

          {:error, reason} ->
            put_status(conn, 400) |> json(%{error: reason})
        end
    end
  end

  def websocket(conn) do
    id = conn.params["id"]

    if TicTacToe.GameServer.alive?(id) do
      Hibana.WebSocket.upgrade(conn, TicTacToe.GameSocket, %{game_id: id})
    else
      put_status(conn, 404) |> json(%{error: "Game not found"})
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(6) |> Base.hex_encode32(case: :lower, padding: false)
  end
end
