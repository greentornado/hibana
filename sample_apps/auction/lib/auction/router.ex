defmodule Auction.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)

  # HTML pages
  get("/", Auction.PageController, :index)
  get("/auction/:id", Auction.PageController, :show)

  # Health check
  get("/health", Auction.ApiController, :health)

  # API endpoints
  get("/api/auctions", Auction.ApiController, :list_auctions)
  get("/api/auctions/:id", Auction.ApiController, :get_auction)
  post("/api/auctions", Auction.ApiController, :create_auction)
  post("/api/auctions/:id/bid", Auction.ApiController, :place_bid)

  # WebSocket upgrade
  get("/ws/auction/:id", Auction.ApiController, :websocket)
end
