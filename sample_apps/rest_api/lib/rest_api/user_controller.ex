defmodule RestApi.UserController do
  use Hibana.Controller

  @users %{
    "1" => %{id: "1", name: "Alice", email: "alice@example.com"},
    "2" => %{id: "2", name: "Bob", email: "bob@example.com"},
    "3" => %{id: "3", name: "Charlie", email: "charlie@example.com"}
  }

  def index(conn) do
    users = Map.values(@users)
    json(conn, %{users: users, total: length(users)})
  end

  def show(conn) do
    id = conn.params["id"]

    case Map.get(@users, id) do
      nil -> put_status(conn, 404) |> json(%{error: "User not found"})
      user -> json(conn, %{user: user})
    end
  end

  def create(conn) do
    body = conn.body_params
    id = :rand.uniform(10000) |> Integer.to_string()

    user = %{
      id: id,
      name: Map.get(body, "name", "Unknown"),
      email: Map.get(body, "email", "unknown@example.com")
    }

    put_status(conn, 201) |> json(%{user: user, message: "User created"})
  end

  def update(conn) do
    id = conn.params["id"]
    body = conn.body_params

    case Map.get(@users, id) do
      nil ->
        put_status(conn, 404) |> json(%{error: "User not found"})

      user ->
        updated = user
          |> Map.put(:name, Map.get(body, "name", user.name))
          |> Map.put(:email, Map.get(body, "email", user.email))
        json(conn, %{user: updated, message: "User updated"})
    end
  end

  def delete(conn) do
    id = conn.params["id"]

    case Map.get(@users, id) do
      nil -> put_status(conn, 404) |> json(%{error: "User not found"})
      _ -> json(conn, %{message: "User deleted"})
    end
  end
end
