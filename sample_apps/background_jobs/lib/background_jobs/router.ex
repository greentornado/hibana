defmodule BackgroundJobs.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get("/", BackgroundJobs.PageController, :index)
  post("/jobs/send-email", BackgroundJobs.PageController, :send_email)
  post("/jobs/welcome-email", BackgroundJobs.PageController, :welcome_email)
  get("/jobs/stats", BackgroundJobs.PageController, :stats)
  post("/jobs/clear", BackgroundJobs.PageController, :clear)
end
