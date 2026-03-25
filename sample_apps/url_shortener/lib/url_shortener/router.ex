defmodule UrlShortener.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.ColorLogger
  plug Hibana.Plugins.ErrorHandler

  # HTML page
  get "/", UrlShortener.RedirectController, :home

  # API
  post "/api/shorten", UrlShortener.ApiController, :shorten
  get "/api/urls", UrlShortener.ApiController, :list_urls
  get "/api/stats/:code", UrlShortener.ApiController, :stats
  delete "/api/urls/:code", UrlShortener.ApiController, :delete_url

  # Redirect (must be last — catches all /:code)
  get "/:code", UrlShortener.RedirectController, :redirect
end
