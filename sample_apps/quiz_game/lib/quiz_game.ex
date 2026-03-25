defmodule QuizGame do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QuizGame.QuizStore,
      QuizGame.GameManager,
      QuizGame.Endpoint
    ]

    opts = [strategy: :one_for_one, name: QuizGame.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
