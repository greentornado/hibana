defmodule Commerce do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Commerce.TableOwner,
      Commerce.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Commerce.Supervisor]
    {:ok, pid} = Supervisor.start_link(children, opts)

    # Seed sample products after tables are created
    seed_products()

    {:ok, pid}
  end

  defp seed_products do
    products = [
      %{
        id: "1",
        name: "Wireless Headphones",
        description: "Noise-cancelling over-ear headphones",
        price: 79.99,
        category: "electronics",
        stock: 50
      },
      %{
        id: "2",
        name: "Ergonomic Keyboard",
        description: "Split mechanical keyboard with Cherry MX switches",
        price: 149.99,
        category: "electronics",
        stock: 30
      },
      %{
        id: "3",
        name: "Running Shoes",
        description: "Lightweight trail running shoes",
        price: 119.99,
        category: "sports",
        stock: 100
      },
      %{
        id: "4",
        name: "Coffee Maker",
        description: "Programmable drip coffee maker with thermal carafe",
        price: 59.99,
        category: "kitchen",
        stock: 25
      },
      %{
        id: "5",
        name: "Backpack",
        description: "Water-resistant 30L daypack with laptop compartment",
        price: 89.99,
        category: "travel",
        stock: 40
      }
    ]

    Enum.each(products, fn product ->
      :ets.insert(:commerce_products, {product.id, product})
    end)
  end
end
