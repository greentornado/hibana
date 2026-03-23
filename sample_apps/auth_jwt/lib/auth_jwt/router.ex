defmodule AuthJwt.Router do
  use Hibana.Router.DSL

  plug(Hibana.Plugins.BodyParser)

  post("/auth/login", AuthJwt.AuthController, :login)
  post("/auth/register", AuthJwt.AuthController, :register)

  plug(Hibana.Plugins.JWT, secret: "super_secret_jwt_key_at_least_32_chars_long")

  get("/protected/profile", AuthJwt.ProfileController, :show)
  get("/protected/settings", AuthJwt.ProfileController, :settings)
end
