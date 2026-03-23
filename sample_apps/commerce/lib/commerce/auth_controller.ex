defmodule Commerce.AuthController do
  use Hibana.Controller

  @jwt_secret "commerce_jwt_secret_key_at_least_32_bytes!"

  @users %{
    "alice@example.com" => %{
      id: "1",
      name: "Alice",
      email: "alice@example.com",
      password: "password123"
    },
    "bob@example.com" => %{
      id: "2",
      name: "Bob",
      email: "bob@example.com",
      password: "secret456"
    },
    "admin@example.com" => %{
      id: "3",
      name: "Admin",
      email: "admin@example.com",
      password: "admin789"
    }
  }

  def register(conn) do
    body = conn.body_params
    email = Map.get(body, "email")
    name = Map.get(body, "name")
    password = Map.get(body, "password")

    cond do
      is_nil(email) or is_nil(name) or is_nil(password) ->
        put_status(conn, 400)
        |> json(%{error: "Missing required fields: name, email, password"})

      Map.has_key?(@users, email) ->
        put_status(conn, 409)
        |> json(%{error: "Email already registered"})

      true ->
        user = %{
          id: :rand.uniform(10000) |> Integer.to_string(),
          name: name,
          email: email
        }

        token = generate_token(user)
        json(conn, %{token: token, user: user, message: "Registration successful"})
    end
  end

  def login(conn) do
    body = conn.body_params
    email = Map.get(body, "email")
    password = Map.get(body, "password")

    case Map.get(@users, email) do
      nil ->
        put_status(conn, 401) |> json(%{error: "Invalid credentials"})

      user when user.password == password ->
        token = generate_token(user)
        json(conn, %{token: token, user: %{id: user.id, name: user.name, email: user.email}})

      _ ->
        put_status(conn, 401) |> json(%{error: "Invalid credentials"})
    end
  end

  defp generate_token(user) do
    claims = %{
      "sub" => user.id,
      "name" => user.name,
      "email" => user.email
    }

    Hibana.Plugins.JWT.sign(claims, @jwt_secret, exp: 3600)
  end
end
