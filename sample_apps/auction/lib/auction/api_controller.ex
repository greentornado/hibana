defmodule Auction.ApiController do
  use Hibana.Controller

  def health(conn) do
    json(conn, %{status: "ok", app: "auction", timestamp: DateTime.utc_now() |> DateTime.to_iso8601()})
  end

  def list_auctions(conn) do
    %{active: active, completed: completed} = Auction.AuctionManager.list_auctions()
    json(conn, %{auctions: active ++ completed, active_count: length(active), completed_count: length(completed)})
  end

  def get_auction(conn) do
    id = conn.params["id"]

    case Auction.AuctionManager.get_auction(id) do
      {:ok, auction} ->
        json(conn, %{auction: auction})

      {:error, :not_found} ->
        put_status(conn, 404) |> json(%{error: "Auction not found"})
    end
  end

  defp parse_number(val) when is_number(val), do: val
  defp parse_number(val) when is_binary(val) do
    case Float.parse(val) do
      {n, _} -> n
      :error -> nil
    end
  end
  defp parse_number(_), do: nil

  def create_auction(conn) do
    body = conn.body_params

    starting_price = parse_number(Map.get(body, "starting_price", 1))
    duration_minutes = parse_number(Map.get(body, "duration_minutes", 5))

    cond do
      is_nil(starting_price) or starting_price <= 0 ->
        put_status(conn, 400) |> json(%{error: "starting_price must be a positive number"})

      is_nil(duration_minutes) or duration_minutes <= 0 ->
        put_status(conn, 400) |> json(%{error: "duration_minutes must be a positive number"})

      true ->
        params = %{
          title: Map.get(body, "title", "Untitled Auction"),
          description: Map.get(body, "description", ""),
          starting_price: starting_price,
          duration_minutes: duration_minutes
        }

    case Auction.AuctionManager.start_auction(params) do
      {:ok, id} ->
        case Auction.AuctionManager.get_auction(id) do
          {:ok, auction} ->
            put_status(conn, 201) |> json(%{auction: auction})

          _ ->
            put_status(conn, 201) |> json(%{auction: %{id: id}})
        end

      {:error, reason} ->
        put_status(conn, 500) |> json(%{error: "Failed to create auction", reason: inspect(reason)})
    end
    end
  end

  def place_bid(conn) do
    id = conn.params["id"]
    body = conn.body_params
    bidder = Map.get(body, "bidder", "Anonymous")
    amount = Map.get(body, "amount")

    cond do
      is_nil(amount) ->
        put_status(conn, 400) |> json(%{error: "Amount is required"})

      not is_number(amount) ->
        put_status(conn, 400) |> json(%{error: "Amount must be a number"})

      true ->
        case Auction.AuctionManager.place_bid(id, bidder, amount) do
          {:ok, auction} ->
            json(conn, %{auction: auction, message: "Bid placed successfully"})

          {:error, {:bid_too_low, min_bid}} ->
            put_status(conn, 400) |> json(%{error: "Bid too low", minimum_bid: min_bid})

          {:error, :auction_ended} ->
            put_status(conn, 400) |> json(%{error: "Auction has ended"})

          {:error, :not_found} ->
            put_status(conn, 404) |> json(%{error: "Auction not found"})
        end
    end
  end

  def websocket(conn) do
    Hibana.WebSocket.upgrade(conn, Auction.AuctionSocket)
  end
end
