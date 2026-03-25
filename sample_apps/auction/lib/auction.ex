defmodule Auction do
  use Application

  def start(_type, _args) do
    children = [
      Auction.AuctionStore,
      {Registry, keys: :unique, name: Auction.AuctionRegistry},
      {DynamicSupervisor, name: Auction.AuctionSupervisor, strategy: :one_for_one},
      Auction.Endpoint
    ]

    opts = [strategy: :one_for_one, name: Auction.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        Auction.AuctionManager.seed()
        {:ok, pid}

      error ->
        error
    end
  end
end
