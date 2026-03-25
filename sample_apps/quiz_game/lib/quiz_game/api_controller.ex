defmodule QuizGame.ApiController do
  use Hibana.Controller

  def health(conn) do
    json(conn, %{status: "ok", app: "quiz_game"})
  end

  def create_quiz(conn) do
    body = conn.body_params

    case validate_quiz(body) do
      :ok ->
        {:ok, quiz} = QuizGame.QuizStore.create(body)
        put_status(conn, 201) |> json(%{quiz: quiz})

      {:error, reason} ->
        put_status(conn, 422) |> json(%{error: reason})
    end
  end

  def list_quizzes(conn) do
    quizzes =
      QuizGame.QuizStore.list()
      |> Enum.map(fn q ->
        %{
          id: q["id"],
          title: q["title"],
          question_count: length(q["questions"])
        }
      end)

    json(conn, %{quizzes: quizzes})
  end

  def create_game(conn) do
    body = conn.body_params
    quiz_id = body["quiz_id"]
    host = body["host"]

    cond do
      is_nil(quiz_id) or is_nil(host) ->
        put_status(conn, 422) |> json(%{error: "quiz_id and host are required"})

      true ->
        case QuizGame.GameManager.create_game(quiz_id, host) do
          {:ok, code} ->
            # Auto-join the host
            QuizGame.GameServer.join(code, host)
            put_status(conn, 201) |> json(%{code: code, host: host})

          {:error, :quiz_not_found} ->
            put_status(conn, 404) |> json(%{error: "Quiz not found"})

          {:error, reason} ->
            put_status(conn, 500) |> json(%{error: inspect(reason)})
        end
    end
  end

  def join_game(conn) do
    code = conn.params["code"]
    body = conn.body_params
    name = body["name"]

    cond do
      is_nil(name) ->
        put_status(conn, 422) |> json(%{error: "name is required"})

      not QuizGame.GameManager.game_exists?(code) ->
        put_status(conn, 404) |> json(%{error: "Game not found"})

      true ->
        case QuizGame.GameServer.join(code, name) do
          {:ok, players} ->
            json(conn, %{code: code, name: name, players: players})

          {:error, :name_taken} ->
            put_status(conn, 409) |> json(%{error: "Name already taken"})

          {:error, :game_in_progress} ->
            put_status(conn, 409) |> json(%{error: "Game already in progress"})
        end
    end
  end

  def game_state(conn) do
    code = conn.params["code"]

    if QuizGame.GameManager.game_exists?(code) do
      {:ok, state} = QuizGame.GameServer.get_state(code)
      json(conn, state)
    else
      put_status(conn, 404) |> json(%{error: "Game not found"})
    end
  end

  def websocket(conn) do
    Hibana.WebSocket.upgrade(conn, QuizGame.GameSocket)
  end

  # Private helpers

  defp validate_quiz(%{"title" => title, "questions" => questions})
       when is_binary(title) and is_list(questions) and length(questions) > 0 do
    if Enum.all?(questions, &valid_question?/1), do: :ok, else: {:error, "invalid question format"}
  end

  defp validate_quiz(_), do: {:error, "title and questions are required"}

  defp valid_question?(%{"text" => t, "options" => opts, "correct" => c})
       when is_binary(t) and is_list(opts) and length(opts) >= 2 and is_integer(c) do
    c >= 0 and c < length(opts)
  end

  defp valid_question?(_), do: false
end
