defmodule TicTacToe.Endpoint do
  use Hibana.Endpoint, otp_app: :tictactoe

  plug TicTacToe.Router
end
