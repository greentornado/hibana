defmodule Commerce.CartController do
  use Hibana.Controller

  def show(conn) do
    cart = Hibana.Controller.get_session(conn, :cart) || []

    # Enrich cart items with current product data
    enriched =
      Enum.map(cart, fn item ->
        case Commerce.Store.get_product(item.product_id) do
          {:ok, product} ->
            %{
              product_id: product.id,
              name: product.name,
              price: product.price,
              quantity: item.quantity,
              subtotal: Float.round(product.price * item.quantity, 2)
            }

          :not_found ->
            %{
              product_id: item.product_id,
              name: "Product unavailable",
              price: 0,
              quantity: item.quantity,
              subtotal: 0
            }
        end
      end)

    total =
      enriched
      |> Enum.reduce(0.0, fn item, acc -> acc + item.subtotal end)
      |> Float.round(2)

    json(conn, %{cart: enriched, total: total, item_count: length(enriched)})
  end

  def add(conn) do
    body = conn.body_params
    product_id = Map.get(body, "product_id")
    quantity = parse_int(Map.get(body, "quantity", 1))

    case Commerce.Store.get_product(product_id) do
      {:ok, product} ->
        cart = Hibana.Controller.get_session(conn, :cart) || []

        # Check if product already in cart
        {cart, updated} =
          case Enum.find_index(cart, &(&1.product_id == product_id)) do
            nil ->
              {cart ++ [%{product_id: product_id, quantity: quantity}], false}

            idx ->
              existing = Enum.at(cart, idx)
              new_item = %{existing | quantity: existing.quantity + quantity}
              {List.replace_at(cart, idx, new_item), true}
          end

        conn = Hibana.Controller.put_session(conn, :cart, cart)

        json(conn, %{
          message: if(updated, do: "Cart updated", else: "Item added to cart"),
          product: %{id: product.id, name: product.name, price: product.price},
          quantity: quantity
        })

      :not_found ->
        put_status(conn, 404) |> json(%{error: "Product not found"})
    end
  end

  def remove(conn) do
    body = conn.body_params
    product_id = Map.get(body, "product_id")
    cart = Hibana.Controller.get_session(conn, :cart) || []

    new_cart = Enum.reject(cart, &(&1.product_id == product_id))

    if length(new_cart) == length(cart) do
      put_status(conn, 404) |> json(%{error: "Item not in cart"})
    else
      conn = Hibana.Controller.put_session(conn, :cart, new_cart)
      json(conn, %{message: "Item removed from cart"})
    end
  end

  def clear(conn) do
    conn = Hibana.Controller.put_session(conn, :cart, [])
    json(conn, %{message: "Cart cleared"})
  end

  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> 1
    end
  end

  defp parse_int(_), do: 1
end
