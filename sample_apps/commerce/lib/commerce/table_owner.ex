defmodule Commerce.TableOwner do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:commerce_products, [:named_table, :set, :public, read_concurrency: true])
    :ets.new(:commerce_orders, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end
end
