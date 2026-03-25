defmodule TypingRace.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)

  # HTML pages
  get("/", TypingRace.PageController, :index)
  get("/race/:code", TypingRace.PageController, :race)

  # API endpoints
  post("/api/races", TypingRace.ApiController, :create)
  post("/api/races/:code/join", TypingRace.ApiController, :join)
  get("/api/races/:code", TypingRace.ApiController, :show)

  # Health check
  get("/health", TypingRace.ApiController, :health)

  # WebSocket
  get("/ws/race/:code", TypingRace.ApiController, :websocket)
end
