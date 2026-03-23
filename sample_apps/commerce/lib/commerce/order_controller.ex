defmodule Commerce.OrderController do
  use Hibana.Controller

  def create(conn) do
    body = conn.body_params
    user_id = conn.assigns[:current_user] || "anonymous"

    # Accept items from body or from session cart
    items = Map.get(body, "items")

    cart = Hibana.Controller.get_session(conn, :cart) || []

    order_items =
      cond do
        is_list(items) and items != [] ->
          items

        cart != [] ->
          Enum.map(cart, fn item ->
            %{"product_id" => item.product_id, "quantity" => item.quantity}
          end)

        true ->
          []
      end

    if order_items == [] do
      put_status(conn, 400) |> json(%{error: "No items to order. Provide items or add to cart first."})
    else
      case Commerce.Store.create_order(order_items, user_id) do
        {:ok, order} ->
          # Clear cart after successful order
          conn = Hibana.Controller.put_session(conn, :cart, [])
          put_status(conn, 201) |> json(%{order: order, message: "Order created"})

        {:error, errors} ->
          put_status(conn, 400) |> json(%{errors: errors})
      end
    end
  end

  def index(conn) do
    user_id = conn.assigns[:current_user]
    orders = Commerce.Store.list_orders()

    # Filter by user if authenticated
    filtered =
      if user_id do
        Enum.filter(orders, &(&1.user_id == user_id))
      else
        orders
      end

    json(conn, %{orders: filtered, total: length(filtered)})
  end

  def show(conn) do
    id = conn.params["id"]

    case Commerce.Store.get_order(id) do
      {:ok, order} ->
        json(conn, %{order: order})

      :not_found ->
        put_status(conn, 404) |> json(%{error: "Order not found"})
    end
  end
end
