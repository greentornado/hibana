defmodule WebhookRelay.ChannelStore do
  @moduledoc """
  ETS-based subscription storage. Maps channel names to lists of subscribers.
  Each subscription: %{id, channel, url, secret, created_at}
  """

  use GenServer

  @table :webhook_subscriptions

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
    {:ok, %{}}
  end

  @doc "Add a subscription to a channel."
  def subscribe(channel, url, secret) do
    id = generate_id()
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    subscription = %{
      id: id,
      channel: channel,
      url: url,
      secret: secret,
      created_at: now
    }

    existing = get_subscriptions(channel)
    :ets.insert(@table, {channel, [subscription | existing]})
    {:ok, subscription}
  end

  @doc "Get all subscriptions for a channel."
  def get_subscriptions(channel) do
    case :ets.lookup(@table, channel) do
      [{^channel, subs}] -> subs
      [] -> []
    end
  end

  @doc "Get all subscriptions across all channels."
  def all_subscriptions do
    :ets.tab2list(@table)
    |> Enum.flat_map(fn {_channel, subs} -> subs end)
  end

  @doc "Delete a subscription by id."
  def delete(id) do
    :ets.tab2list(@table)
    |> Enum.each(fn {channel, subs} ->
      updated = Enum.reject(subs, fn s -> s.id == id end)

      if length(updated) != length(subs) do
        if updated == [] do
          :ets.delete(@table, channel)
        else
          :ets.insert(@table, {channel, updated})
        end
      end
    end)

    :ok
  end

  @doc "Find a subscription by id."
  def find(id) do
    all_subscriptions()
    |> Enum.find(fn s -> s.id == id end)
  end

  @doc "Count of unique channels."
  def channel_count do
    :ets.info(@table, :size)
  end

  @doc "Count subscribers for a channel."
  def subscriber_count(channel) do
    get_subscriptions(channel) |> length()
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.hex_encode32(case: :lower, padding: false)
  end
end
