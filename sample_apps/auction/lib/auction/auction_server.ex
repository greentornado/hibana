defmodule Auction.AuctionServer do
  @moduledoc """
  GenServer managing a single auction's state, bids, timer, and subscribers.
  Auto-closes when duration expires. Anti-sniping extends by 30s for late bids.
  """

  use GenServer

  @countdown_interval 1_000
  @snipe_window 30

  # --- Client API ---

  def start_link(params) do
    GenServer.start_link(__MODULE__, params,
      name: {:via, Registry, {Auction.AuctionRegistry, params.id}}
    )
  end

  def child_spec(params) do
    %{
      id: {__MODULE__, params.id},
      start: {__MODULE__, :start_link, [params]},
      restart: :temporary
    }
  end

  def get_state(pid), do: GenServer.call(pid, :get_state)

  def place_bid(pid, bidder, amount), do: GenServer.call(pid, {:bid, bidder, amount})

  def subscribe(pid, subscriber_pid), do: GenServer.cast(pid, {:subscribe, subscriber_pid})

  def unsubscribe(pid, subscriber_pid), do: GenServer.cast(pid, {:unsubscribe, subscriber_pid})

  # --- Server Callbacks ---

  @impl true
  def init(params) do
    duration_seconds = (params[:duration_minutes] || params.duration_minutes) * 60
    now = System.system_time(:second)

    state = %{
      id: params.id,
      title: params.title,
      description: params[:description] || "",
      starting_price: params.starting_price,
      current_price: params.starting_price,
      highest_bidder: nil,
      bids: [],
      subscribers: MapSet.new(),
      started_at: now,
      ends_at: now + duration_seconds,
      status: :active,
      min_increment: max(trunc(params.starting_price * 0.1), 1)
    }

    schedule_countdown()

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, {:ok, public_state(state)}, state}
  end

  def handle_call({:bid, bidder, amount}, _from, state) do
    cond do
      state.status != :active ->
        {:reply, {:error, :auction_ended}, state}

      amount < state.current_price + state.min_increment ->
        min_bid = state.current_price + state.min_increment
        {:reply, {:error, {:bid_too_low, min_bid}}, state}

      true ->
        now = System.system_time(:second)
        time_remaining = max(state.ends_at - now, 0)

        # Anti-sniping: extend by 30s if bid in last 30 seconds
        new_ends_at =
          if time_remaining <= @snipe_window do
            now + @snipe_window
          else
            state.ends_at
          end

        bid_entry = %{
          bidder: bidder,
          amount: amount,
          time: now
        }

        new_state = %{
          state
          | current_price: amount,
            highest_bidder: bidder,
            bids: [bid_entry | state.bids],
            ends_at: new_ends_at
        }

        new_time_remaining = max(new_ends_at - now, 0)

        broadcast(new_state, %{
          type: "new_bid",
          bidder: bidder,
          amount: amount,
          time_remaining: new_time_remaining
        })

        # Notify others they've been outbid
        broadcast(new_state, %{
          type: "outbid",
          by: bidder,
          amount: amount
        })

        {:reply, {:ok, public_state(new_state)}, new_state}
    end
  end

  @impl true
  def handle_cast({:subscribe, pid}, state) do
    if MapSet.member?(state.subscribers, pid) do
      {:noreply, state}
    else
      Process.monitor(pid)
      new_state = %{state | subscribers: MapSet.put(state.subscribers, pid)}

      # Send bid history to the new subscriber
      send(
        pid,
        {:auction_msg,
         Jason.encode!(%{
           type: "bid_history",
           bids: Enum.reverse(state.bids)
         })}
      )

      {:noreply, new_state}
    end
  end

  def handle_cast({:unsubscribe, pid}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  @impl true
  def handle_info(:countdown, state) do
    now = System.system_time(:second)
    time_remaining = max(state.ends_at - now, 0)

    if time_remaining <= 0 do
      end_auction(state)
    else
      if time_remaining <= 60 do
        broadcast(state, %{type: "countdown", seconds: time_remaining})
      end

      schedule_countdown()
      {:noreply, state}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: MapSet.delete(state.subscribers, pid)}}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  # --- Private ---

  defp end_auction(state) do
    final_state = %{state | status: :ended}

    result = %{
      type: "auction_ended",
      winner: state.highest_bidder,
      final_price: state.current_price
    }

    broadcast(final_state, result)

    # Persist to ETS store
    Auction.AuctionStore.put(state.id, public_state(final_state))

    {:stop, :normal, final_state}
  end

  defp schedule_countdown do
    Process.send_after(self(), :countdown, @countdown_interval)
  end

  defp broadcast(state, message) do
    encoded = Jason.encode!(message)

    Enum.each(state.subscribers, fn pid ->
      send(pid, {:auction_msg, encoded})
    end)
  end

  defp public_state(state) do
    now = System.system_time(:second)
    time_remaining = if state.status == :active, do: max(state.ends_at - now, 0), else: 0

    %{
      id: state.id,
      title: state.title,
      description: state.description,
      starting_price: state.starting_price,
      current_price: state.current_price,
      highest_bidder: state.highest_bidder,
      bid_count: length(state.bids),
      bids: Enum.reverse(state.bids) |> Enum.take(-20),
      status: state.status,
      time_remaining: time_remaining,
      min_increment: state.min_increment
    }
  end
end
