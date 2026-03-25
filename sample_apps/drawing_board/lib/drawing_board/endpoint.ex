defmodule DrawingBoard.Endpoint do
  use Hibana.Endpoint, otp_app: :drawing_board

  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.Logger)
  plug(DrawingBoard.Router)
end
