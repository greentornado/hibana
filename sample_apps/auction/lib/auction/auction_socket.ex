defmodule Auction.AuctionSocket do
  @moduledoc """
  WebSocket handler for real-time auction bid updates.
  Subscribes to the auction server and forwards bid events to the client.
  Accepts bids from clients via JSON messages.
  """

  use Hibana.WebSocket

  def init(conn, _opts) do
    auction_id = conn.params["id"]
    name = conn.query_params["name"] || "Anonymous"

    {:ok, conn, %{auction_id: auction_id, name: name}}
  end

  def handle_connect(_info, state) do
    case Auction.AuctionManager.subscribe(state.auction_id, self()) do
      :ok -> {:ok, state}
      {:error, _} -> {:stop, state}
    end
  end

  def handle_disconnect(_reason, state) do
    Auction.AuctionManager.unsubscribe(state.auction_id, self())
    {:ok, state}
  end

  def handle_in(message, state) do
    case Jason.decode(message) do
      {:ok, %{"type" => "bid", "amount" => amount}} when is_number(amount) ->
        case Auction.AuctionManager.place_bid(state.auction_id, state.name, amount) do
          {:ok, _auction} ->
            {:ok, state}

          {:error, {:bid_too_low, min_bid}} ->
            error = Jason.encode!(%{type: "error", message: "Bid too low. Minimum: $#{min_bid}"})
            {:reply, {:text, error}, state}

          {:error, :auction_ended} ->
            error = Jason.encode!(%{type: "error", message: "Auction has ended"})
            {:reply, {:text, error}, state}

          {:error, _reason} ->
            error = Jason.encode!(%{type: "error", message: "Failed to place bid"})
            {:reply, {:text, error}, state}
        end

      _ ->
        error = Jason.encode!(%{type: "error", message: "Invalid message format"})
        {:reply, {:text, error}, state}
    end
  end

  def handle_info({:auction_msg, encoded_message}, state) do
    {:push, {:text, encoded_message}, state}
  end

  def handle_info(_message, state) do
    {:ok, state}
  end
end
