defmodule RestApi.PostController do
  use Hibana.Controller

  @posts %{
    "1" => %{id: "1", title: "Hello World", content: "My first post"},
    "2" => %{id: "2", title: "Elixir is Awesome", content: "Learning Elixir..."}
  }

  def index(conn) do
    posts = Map.values(@posts)
    json(conn, %{posts: posts, total: length(posts)})
  end

  def show(conn) do
    id = conn.params["id"]

    case Map.get(@posts, id) do
      nil -> put_status(conn, 404) |> json(%{error: "Post not found"})
      post -> json(conn, %{post: post})
    end
  end

  def create(conn) do
    body = conn.body_params
    id = :rand.uniform(10000) |> Integer.to_string()

    post = %{
      id: id,
      title: Map.get(body, "title", "Untitled"),
      content: Map.get(body, "content", "")
    }

    put_status(conn, 201) |> json(%{post: post, message: "Post created"})
  end
end
