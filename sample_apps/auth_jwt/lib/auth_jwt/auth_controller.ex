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
    body = conn.body_params || %{}
    email = Map.get(body, "email")
    password = Map.get(body, "password")

    if is_nil(email) or is_nil(password) do
      put_status(conn, 400) |> json(%{error: "email and password are required"})
    else
      case Map.get(@users, email) do
        nil ->
          put_status(conn, 401) |> json(%{error: "Invalid credentials"})

        user when is_binary(password) and is_binary(user.password) ->
          if Plug.Crypto.secure_compare(user.password, password) do
            token = generate_token(user)
            json(conn, %{token: token, user: %{id: user.id, name: user.name, email: user.email}})
          else
            put_status(conn, 401) |> json(%{error: "Invalid credentials"})
          end

        _ ->
          put_status(conn, 401) |> json(%{error: "Invalid credentials"})
      end
    end
  end

  def register(conn) do
    body = conn.body_params || %{}
    name = Map.get(body, "name")
    email = Map.get(body, "email")
    password = Map.get(body, "password")

    if is_nil(name) or is_nil(email) or is_nil(password) do
      put_status(conn, 400) |> json(%{error: "name, email, and password are required"})
    else
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
