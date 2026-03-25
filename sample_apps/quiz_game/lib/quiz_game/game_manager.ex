defmodule QuizGame.GameManager do
  @moduledoc """
  Manages game lifecycles using a Registry and DynamicSupervisor.
  Creates new game servers and generates unique game codes.
  """

  use Supervisor

  def start_link(_opts) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      {Registry, keys: :unique, name: QuizGame.GameRegistry},
      {DynamicSupervisor, name: QuizGame.GameSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end

  @doc "Create a new game from a quiz ID and host name. Returns {:ok, code}."
  def create_game(quiz_id, host) do
    case QuizGame.QuizStore.get(quiz_id) do
      {:ok, quiz} ->
        code = generate_code()

        case DynamicSupervisor.start_child(
               QuizGame.GameSupervisor,
               {QuizGame.GameServer, {code, quiz, host}}
             ) do
          {:ok, _pid} -> {:ok, code}
          {:error, reason} -> {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :quiz_not_found}
    end
  end

  @doc "Check if a game exists by code."
  def game_exists?(code) do
    case Registry.lookup(QuizGame.GameRegistry, code) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  defp generate_code do
    code =
      :rand.uniform(9999)
      |> Integer.to_string()
      |> String.pad_leading(4, "0")

    if game_exists?(code), do: generate_code(), else: code
  end
end
