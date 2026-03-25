defmodule QuizGame.GameSocket do
  @moduledoc """
  WebSocket handler for real-time game communication.
  Players connect with /ws/game/:code?name=PlayerName
  """

  use Hibana.WebSocket

  def init(conn, _opts) do
    code = conn.params["code"]
    name = conn.query_params["name"] || conn.params["name"]

    if code && name && QuizGame.GameManager.game_exists?(code) do
      {:ok, conn, %{code: code, name: name}}
    else
      {:halt, conn}
    end
  end

  def handle_connect(_info, state) do
    # Register this WebSocket process with the game server
    QuizGame.GameServer.register_player_pid(state.code, state.name, self())

    # Send current game state to the connecting player
    case QuizGame.GameServer.get_state(state.code) do
      {:ok, game_state} ->
        msg = Jason.encode!(%{
          type: "connected",
          code: state.code,
          name: state.name,
          players: game_state.players,
          status: game_state.status
        })
        send(self(), {:send_text, msg})
        {:ok, state}

      _ ->
        {:ok, state}
    end
  end

  def handle_disconnect(_reason, state) do
    QuizGame.GameServer.unregister_player_pid(state.code, state.name)
    {:ok, state}
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "start"}} ->
        case QuizGame.GameServer.start_game(state.code) do
          :ok ->
            {:ok, state}

          {:error, reason} ->
            reply = Jason.encode!(%{type: "error", message: to_string(reason)})
            {:reply, {:text, reply}, state}
        end

      {:ok, %{"type" => "answer", "option" => option}} when is_integer(option) ->
        case QuizGame.GameServer.submit_answer(state.code, state.name, option) do
          {:ok, points} ->
            reply = Jason.encode!(%{type: "answer_accepted", points: points})
            {:reply, {:text, reply}, state}

          {:error, reason} ->
            reply = Jason.encode!(%{type: "error", message: to_string(reason)})
            {:reply, {:text, reply}, state}
        end

      {:ok, _} ->
        reply = Jason.encode!(%{type: "error", message: "unknown message type"})
        {:reply, {:text, reply}, state}

      {:error, _} ->
        reply = Jason.encode!(%{type: "error", message: "invalid JSON"})
        {:reply, {:text, reply}, state}
    end
  end

  def handle_info({:broadcast, encoded_msg}, state) do
    {:push, {:text, encoded_msg}, state}
  end

  def handle_info({:send_text, msg}, state) do
    {:push, {:text, msg}, state}
  end

  def handle_info(_msg, state) do
    {:ok, state}
  end
end
