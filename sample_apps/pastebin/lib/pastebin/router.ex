defmodule Pastebin.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.ErrorHandler

  # HTML pages
  get "/", Pastebin.PageController, :home
  get "/p/:id", Pastebin.PageController, :view_paste
  get "/raw/:id", Pastebin.PageController, :raw

  # API
  post "/api/pastes", Pastebin.ApiController, :create
  get "/api/pastes", Pastebin.ApiController, :list_recent
  get "/api/pastes/:id", Pastebin.ApiController, :show
  delete "/api/pastes/:id", Pastebin.ApiController, :delete_paste
end
