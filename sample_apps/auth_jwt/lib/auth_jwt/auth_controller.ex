defmodule AuthJwt.AuthController do
  use Hibana.Controller

  @users %{
    "alice@example.com" => %{
      id: "1",
      name: "Alice",
      email: "alice@example.com",
      password: "password123"
    },
    "bob@example.com" => %{id: "2", name: "Bob", email: "bob@example.com", password: "secret456"}
  }

  @jwt_secret "super_secret_jwt_key_at_least_32_chars_long"

  def login(conn) do
    %{"email" => email, "password" => password} = conn.body_params

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

  def register(conn) do
    %{"name" => name, "email" => email, "password" => _password} = conn.body_params

    case Map.get(@users, email) do
      nil ->
        user = %{id: :rand.uniform(10000) |> Integer.to_string(), name: name, email: email}
        token = generate_token(user)

        put_status(conn, 201)
        |> json(%{token: token, user: user, message: "Registration successful"})

      _ ->
        put_status(conn, 409) |> json(%{error: "Email already registered"})
    end
  end

  defp generate_token(user) do
    claims = %{
      "sub" => user.id,
      "name" => user.name,
      "email" => user.email
    }

    Hibana.Plugins.JWT.sign(claims, @jwt_secret)
  end
end
