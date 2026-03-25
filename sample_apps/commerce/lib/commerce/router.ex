defmodule Commerce.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.CORS
  plug Hibana.Plugins.Compression
  plug Hibana.Plugins.HealthCheck
  plug Hibana.Plugins.Metrics
  plug Hibana.Plugins.Logger
  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.Session, secret: "commerce_session_secret_key_at_least_32_bytes!"

  # Public auth routes
  post("/auth/register", Commerce.AuthController, :register)
  post("/auth/login", Commerce.AuthController, :login)

  # Public product read routes
  get("/products", Commerce.ProductController, :index)
  get("/products/:id", Commerce.ProductController, :show)

  # Cart routes (session-based, no JWT needed)
  get("/cart", Commerce.CartController, :show)
  post("/cart/add", Commerce.CartController, :add)
  post("/cart/remove", Commerce.CartController, :remove)
  delete("/cart", Commerce.CartController, :clear)

  # JWT-protected routes
  plug Hibana.Plugins.JWT, secret: "commerce_jwt_secret_key_at_least_32_bytes!"

  # Protected product write routes
  post("/products", Commerce.ProductController, :create)
  put("/products/:id", Commerce.ProductController, :update)
  delete("/products/:id", Commerce.ProductController, :delete)

  # Protected order routes
  post("/orders", Commerce.OrderController, :create)
  get("/orders", Commerce.OrderController, :index)
  get("/orders/:id", Commerce.OrderController, :show)
end
