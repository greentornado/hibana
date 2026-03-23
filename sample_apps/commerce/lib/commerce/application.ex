defmodule Commerce do
  use Application

  def start(_type, _args) do
    # Create ETS tables for product and order storage
    :ets.new(:commerce_products, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(:commerce_orders, [:named_table, :set, :public, read_concurrency: true])

    # Seed sample products
    seed_products()

    children = [
      Commerce.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Commerce.Supervisor]
    Supervisor.start_link(children, opts)
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
