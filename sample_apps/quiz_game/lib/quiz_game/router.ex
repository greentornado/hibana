defmodule QuizGame.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  # HTML UI
  get "/", QuizGame.PageController, :index

  # Static files
  get "/static/:file", QuizGame.PageController, :static

  # Health check
  get "/health", QuizGame.ApiController, :health

  # Quiz CRUD
  post "/api/quizzes", QuizGame.ApiController, :create_quiz
  get "/api/quizzes", QuizGame.ApiController, :list_quizzes

  # Game management
  post "/api/games", QuizGame.ApiController, :create_game
  post "/api/games/:code/join", QuizGame.ApiController, :join_game
  get "/api/games/:code", QuizGame.ApiController, :game_state

  # WebSocket upgrade
  get "/ws/game/:code", QuizGame.ApiController, :websocket
end
