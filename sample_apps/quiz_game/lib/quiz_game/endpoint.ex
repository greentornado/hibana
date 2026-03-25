defmodule QuizGame.Endpoint do
  use Hibana.Endpoint, otp_app: :quiz_game

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger
  plug QuizGame.Router
end
