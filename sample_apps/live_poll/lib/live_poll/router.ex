defmodule LivePoll.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)
  plug(Hibana.Plugins.RequestId)
  plug(Hibana.Plugins.Logger)

  # HTML pages
  get("/", LivePoll.PageController, :index)
  get("/poll/:id", LivePoll.PageController, :show)

  # Health check
  get("/health", LivePoll.ApiController, :health)

  # API endpoints
  get("/api/polls", LivePoll.ApiController, :list_polls)
  post("/api/polls", LivePoll.ApiController, :create_poll)
  get("/api/polls/:id", LivePoll.ApiController, :get_poll)
  post("/api/polls/:id/vote", LivePoll.ApiController, :vote)
  get("/api/polls/:id/stream", LivePoll.ApiController, :stream)
end
