defmodule Commerce.Store do
  @moduledoc """
  ETS-based storage for products and orders.
  """

  # --- Products ---

  def list_products do
    :ets.tab2list(:commerce_products)
    |> Enum.map(fn {_id, product} -> product end)
  end

  def get_product(id) do
    case :ets.lookup(:commerce_products, id) do
      [{^id, product}] -> {:ok, product}
      [] -> :not_found
    end
  end

  def create_product(attrs) do
    price = parse_float(Map.get(attrs, "price", 0))
    stock = parse_int(Map.get(attrs, "stock", 0))

    cond do
      price <= 0 ->
        {:error, "Price must be positive"}

      stock < 0 ->
        {:error, "Stock cannot be negative"}

      true ->
        id = generate_id()

        product = %{
          id: id,
          name: Map.get(attrs, "name", "Unnamed"),
          description: Map.get(attrs, "description", ""),
          price: price,
          category: Map.get(attrs, "category", "general"),
          stock: stock
        }

        :ets.insert(:commerce_products, {id, product})
        {:ok, product}
    end
  end

  def update_product(id, attrs) do
    case get_product(id) do
      {:ok, product} ->
        updated =
          product
          |> maybe_update(:name, attrs)
          |> maybe_update(:description, attrs)
          |> maybe_update(:category, attrs)
          |> maybe_update_number(:price, attrs, &parse_float/1)
          |> maybe_update_number(:stock, attrs, &parse_int/1)

        :ets.insert(:commerce_products, {id, updated})
        {:ok, updated}

      :not_found ->
        :not_found
    end
  end

  def delete_product(id) do
    case get_product(id) do
      {:ok, _product} ->
        :ets.delete(:commerce_products, id)
        :ok

      :not_found ->
        :not_found
    end
  end

  # --- Orders ---

  def list_orders do
    :ets.tab2list(:commerce_orders)
    |> Enum.map(fn {_id, order} -> order end)
    |> Enum.sort_by(& &1.created_at, :desc)
  end

  def get_order(id) do
    case :ets.lookup(:commerce_orders, id) do
      [{^id, order}] -> {:ok, order}
      [] -> :not_found
    end
  end

  def create_order(items, user_id) do
    # Validate all items exist and calculate total
    validated_items =
      Enum.map(items, fn item ->
        product_id = Map.get(item, "product_id") || Map.get(item, :product_id)
        quantity = parse_int(Map.get(item, "quantity") || Map.get(item, :quantity, 1))

        cond do
          quantity <= 0 ->
            {:error, "Quantity must be positive"}

          true ->
            case get_product(product_id) do
              {:ok, product} ->
                if quantity > product.stock do
                  {:error, "Insufficient stock for product #{product_id}"}
                else
                  {:ok,
                   %{
                     product_id: product.id,
                     name: product.name,
                     price: product.price,
                     quantity: quantity,
                     subtotal: product.price * quantity
                   }}
                end

              :not_found ->
                {:error, "Product #{product_id} not found"}
            end
        end
      end)

    errors = Enum.filter(validated_items, &match?({:error, _}, &1))

    if errors == [] do
      order_items = Enum.map(validated_items, fn {:ok, item} -> item end)
      total = Enum.reduce(order_items, 0.0, fn item, acc -> acc + item.subtotal end)
      total = Float.round(total, 2)

      id = generate_id()

      order = %{
        id: id,
        user_id: user_id,
        items: order_items,
        total: total,
        status: "pending",
        created_at: DateTime.utc_now() |> DateTime.to_iso8601()
      }

      # Decrement stock for each product
      Enum.each(order_items, fn item ->
        case get_product(item.product_id) do
          {:ok, product} ->
            new_stock = product.stock - item.quantity

            if new_stock >= 0 do
              updated = %{product | stock: new_stock}
              :ets.insert(:commerce_products, {product.id, updated})
            end

          _ ->
            :ok
        end
      end)

      :ets.insert(:commerce_orders, {id, order})
      {:ok, order}
    else
      {:error, Enum.map(errors, fn {:error, msg} -> msg end)}
    end
  end

  # --- Helpers ---

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)
  end

  defp parse_float(val) when is_float(val), do: val
  defp parse_float(val) when is_integer(val), do: val * 1.0

  defp parse_float(val) when is_binary(val) do
    case Float.parse(val) do
      {f, _} -> f
      :error -> 0.0
    end
  end

  defp parse_float(_), do: 0.0

  defp parse_int(val) when is_integer(val), do: val

  defp parse_int(val) when is_binary(val) do
    case Integer.parse(val) do
      {i, _} -> i
      :error -> 0
    end
  end

  defp parse_int(_), do: 0

  defp maybe_update(map, key, attrs) do
    str_key = Atom.to_string(key)

    if Map.has_key?(attrs, str_key) do
      Map.put(map, key, Map.get(attrs, str_key))
    else
      map
    end
  end

  defp maybe_update_number(map, key, attrs, parser) do
    str_key = Atom.to_string(key)

    if Map.has_key?(attrs, str_key) do
      Map.put(map, key, parser.(Map.get(attrs, str_key)))
    else
      map
    end
  end
end
