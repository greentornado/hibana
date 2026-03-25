defmodule QuizGame.QuizStore do
  @moduledoc """
  ETS-based storage for quiz templates. Seeds sample quizzes on startup.
  """

  use GenServer

  @table :quiz_store

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def create(quiz) do
    id = generate_id()
    quiz = Map.put(quiz, "id", id)
    :ets.insert(@table, {id, quiz})
    {:ok, quiz}
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, quiz}] -> {:ok, quiz}
      [] -> {:error, :not_found}
    end
  end

  def list do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, quiz} -> quiz end)
  end

  # Server callbacks

  @impl true
  def init(_) do
    table = :ets.new(@table, [:named_table, :public, :set])
    seed_quizzes()
    {:ok, table}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false) |> binary_part(0, 8)
  end

  defp seed_quizzes do
    geography = %{
      "id" => "geo1",
      "title" => "World Geography",
      "questions" => [
        %{
          "text" => "What is the capital of France?",
          "options" => ["London", "Paris", "Berlin", "Rome"],
          "correct" => 1,
          "time_limit" => 15
        },
        %{
          "text" => "What is the capital of Japan?",
          "options" => ["Beijing", "Seoul", "Tokyo", "Bangkok"],
          "correct" => 2,
          "time_limit" => 15
        },
        %{
          "text" => "What is the capital of Brazil?",
          "options" => ["Rio de Janeiro", "Sao Paulo", "Brasilia", "Buenos Aires"],
          "correct" => 2,
          "time_limit" => 15
        },
        %{
          "text" => "What is the capital of Australia?",
          "options" => ["Sydney", "Melbourne", "Canberra", "Perth"],
          "correct" => 2,
          "time_limit" => 15
        },
        %{
          "text" => "What is the capital of Canada?",
          "options" => ["Toronto", "Vancouver", "Montreal", "Ottawa"],
          "correct" => 3,
          "time_limit" => 15
        }
      ]
    }

    programming = %{
      "id" => "prog1",
      "title" => "Programming Trivia",
      "questions" => [
        %{
          "text" => "Who created the Python programming language?",
          "options" => ["James Gosling", "Guido van Rossum", "Bjarne Stroustrup", "Dennis Ritchie"],
          "correct" => 1,
          "time_limit" => 15
        },
        %{
          "text" => "What does HTML stand for?",
          "options" => [
            "Hyper Text Markup Language",
            "High Tech Modern Language",
            "Hyper Transfer Markup Language",
            "Home Tool Markup Language"
          ],
          "correct" => 0,
          "time_limit" => 15
        },
        %{
          "text" => "Which language is used for the BEAM virtual machine?",
          "options" => ["Haskell", "Scala", "Erlang", "Clojure"],
          "correct" => 2,
          "time_limit" => 15
        },
        %{
          "text" => "What year was JavaScript first released?",
          "options" => ["1993", "1995", "1997", "2000"],
          "correct" => 1,
          "time_limit" => 15
        },
        %{
          "text" => "Which company developed the Go programming language?",
          "options" => ["Microsoft", "Apple", "Google", "Facebook"],
          "correct" => 2,
          "time_limit" => 15
        }
      ]
    }

    :ets.insert(@table, {"geo1", geography})
    :ets.insert(@table, {"prog1", programming})
  end
end
