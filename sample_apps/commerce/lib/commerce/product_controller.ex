defmodule Commerce.ProductController do
  use Hibana.Controller

  def index(conn) do
    products = Commerce.Store.list_products()

    # Optional filtering by category
    category = conn.query_params["category"]

    filtered =
      if category do
        Enum.filter(products, &(&1.category == category))
      else
        products
      end

    json(conn, %{products: filtered, total: length(filtered)})
  end

  def show(conn) do
    id = conn.params["id"]

    case Commerce.Store.get_product(id) do
      {:ok, product} ->
        json(conn, %{product: product})

      :not_found ->
        put_status(conn, 404) |> json(%{error: "Product not found"})
    end
  end

  def create(conn) do
    body = conn.body_params

    case Commerce.Store.create_product(body) do
      {:ok, product} ->
        put_status(conn, 201) |> json(%{product: product, message: "Product created"})

      {:error, reason} ->
        put_status(conn, 400) |> json(%{error: reason})
    end
  end

  def update(conn) do
    id = conn.params["id"]
    body = conn.body_params

    case Commerce.Store.update_product(id, body) do
      {:ok, product} ->
        json(conn, %{product: product, message: "Product updated"})

      :not_found ->
        put_status(conn, 404) |> json(%{error: "Product not found"})
    end
  end

  def delete(conn) do
    id = conn.params["id"]

    case Commerce.Store.delete_product(id) do
      :ok ->
        json(conn, %{message: "Product deleted"})

      :not_found ->
        put_status(conn, 404) |> json(%{error: "Product not found"})
    end
  end
end
