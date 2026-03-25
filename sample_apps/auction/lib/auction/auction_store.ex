defmodule Auction.AuctionStore do
  @moduledoc """
  ETS-based store for completed auctions and auction metadata.
  """

  use GenServer

  @table :auction_store

  def start_link(_opts \\ []) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_opts) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  def put(id, auction_data) do
    :ets.insert(@table, {id, auction_data})
    :ok
  end

  def get(id) do
    case :ets.lookup(@table, id) do
      [{^id, data}] -> {:ok, data}
      [] -> :error
    end
  end

  def all do
    :ets.tab2list(@table)
    |> Enum.map(fn {_id, data} -> data end)
  end

  def delete(id) do
    :ets.delete(@table, id)
    :ok
  end
end
