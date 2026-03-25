defmodule Auction.AuctionManager do
  @moduledoc """
  Manages auction lifecycle using Registry and DynamicSupervisor.
  """

  def start_auction(params) do
    id = generate_id()

    spec = {Auction.AuctionServer, Map.put(params, :id, id)}

    case DynamicSupervisor.start_child(Auction.AuctionSupervisor, spec) do
      {:ok, _pid} -> {:ok, id}
      {:error, reason} -> {:error, reason}
    end
  end

  def get_auction(id) do
    case lookup(id) do
      {:ok, pid} -> Auction.AuctionServer.get_state(pid)
      :error -> get_completed(id)
    end
  end

  def place_bid(id, bidder, amount) do
    case lookup(id) do
      {:ok, pid} -> Auction.AuctionServer.place_bid(pid, bidder, amount)
      :error -> {:error, :not_found}
    end
  end

  def list_auctions do
    active =
      Registry.select(Auction.AuctionRegistry, [{{:"$1", :"$2", :_}, [], [{{:"$1", :"$2"}}]}])
      |> Enum.map(fn {_id, pid} ->
        case Auction.AuctionServer.get_state(pid) do
          {:ok, state} -> state
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    completed = Auction.AuctionStore.all()

    %{active: active, completed: completed}
  end

  def subscribe(auction_id, pid) do
    case lookup(auction_id) do
      {:ok, server_pid} ->
        Auction.AuctionServer.subscribe(server_pid, pid)
        :ok

      :error ->
        {:error, :not_found}
    end
  end

  def unsubscribe(auction_id, pid) do
    case lookup(auction_id) do
      {:ok, server_pid} -> Auction.AuctionServer.unsubscribe(server_pid, pid)
      :error -> :ok
    end
  end

  def seed do
    auctions = [
      %{
        title: "Vintage Mechanical Watch",
        description:
          "A beautifully restored 1960s Swiss mechanical watch with original movement. Features a cream dial, gold-plated case, and genuine leather strap.",
        starting_price: 100,
        duration_minutes: 5
      },
      %{
        title: "Rare First Edition Book",
        description:
          "First edition hardcover of a classic novel in excellent condition. Includes original dust jacket with minimal wear. A true collector's item.",
        starting_price: 50,
        duration_minutes: 5
      },
      %{
        title: "Handcrafted Wooden Chess Set",
        description:
          "Artisan-made chess set carved from walnut and maple. Each piece is hand-turned with exquisite detail. Board folds for storage with felt-lined interior.",
        starting_price: 75,
        duration_minutes: 5
      }
    ]

    Enum.each(auctions, fn params -> start_auction(params) end)
  end

  defp lookup(id) do
    case Registry.lookup(Auction.AuctionRegistry, id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  defp get_completed(id) do
    case Auction.AuctionStore.get(id) do
      {:ok, data} -> {:ok, data}
      :error -> {:error, :not_found}
    end
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)
  end
end
