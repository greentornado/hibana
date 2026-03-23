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

  def login(conn) do
    %{email: email, password: password} = conn.body_params

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
    %{name: name, email: email, password: _password} = conn.body_params

    case Map.get(@users, email) do
      nil ->
        user = %{id: :rand.uniform(10000) |> Integer.to_string(), name: name, email: email}
        token = generate_token(user)
        json(conn, %{token: token, user: user, message: "Registration successful"})

      _ ->
        put_status(conn, 409) |> json(%{error: "Email already registered"})
    end
  end

  defp generate_token(user) do
    claims = %{
      "sub" => user.id,
      "name" => user.name,
      "email" => user.email,
      "exp" => System.system_time(:second) + 3600
    }

    jwk = JOSE.JWK.from_oct("super-secret-key-for-jwt-signing-min-32-bytes!")
    {_, token} = JOSE.JWT.sign(jwk, %{"alg" => "HS256"}, claims) |> JOSE.JWS.compact()
    token
  end
end
