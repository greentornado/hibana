defmodule AuthJwt.ProfileController do
  use Hibana.Controller

  def show(conn) do
    user = conn.assigns[:jwt_payload] || %{}

    json(conn, %{
      profile: %{
        id: Map.get(user, "sub", "unknown"),
        name: Map.get(user, "name", "Unknown"),
        email: Map.get(user, "email", "unknown@example.com"),
        bio: "This is a protected profile"
      }
    })
  end

  def settings(conn) do
    user = conn.assigns[:jwt_payload] || %{}

    json(conn, %{
      settings: %{
        user_id: Map.get(user, "sub", "unknown"),
        theme: "dark",
        notifications: true,
        language: "en"
      }
    })
  end
end
