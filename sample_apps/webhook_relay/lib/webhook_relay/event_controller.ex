defmodule WebhookRelay.EventController do
  use Hibana.Controller

  @doc "GET /api/events - List recent events with delivery status."
  def index(conn) do
    limit = conn.params["limit"] |> parse_int(50)
    events = WebhookRelay.EventStore.list_events(limit)

    summary =
      Enum.map(events, fn e ->
        %{
          id: e.id,
          channel: e.channel,
          received_at: e.received_at,
          delivery_count: length(e.deliveries),
          statuses: Enum.map(e.deliveries, & &1.status) |> Enum.uniq()
        }
      end)

    json(conn, %{events: summary, total: length(summary)})
  end

  @doc "GET /api/events/:id - Event detail with payload and delivery attempts."
  def show(conn) do
    id = conn.params["id"]

    case WebhookRelay.EventStore.get_event(id) do
      {:ok, event} ->
        json(conn, %{event: event})

      {:error, :not_found} ->
        put_status(conn, 404)
        |> json(%{error: "Event not found"})
    end
  end

  @doc "GET /api/channels/:name/stats - Channel statistics."
  def channel_stats(conn) do
    name = conn.params["name"]
    event_count = WebhookRelay.EventStore.event_count(name)
    subscriber_count = WebhookRelay.ChannelStore.subscriber_count(name)
    last_event = WebhookRelay.EventStore.last_event(name)

    last_event_at =
      if last_event do
        last_event.received_at
      else
        nil
      end

    json(conn, %{
      channel: name,
      event_count: event_count,
      subscriber_count: subscriber_count,
      last_event_at: last_event_at
    })
  end

  defp parse_int(nil, default), do: default
  defp parse_int(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end
  defp parse_int(val, _default) when is_integer(val), do: val
  defp parse_int(_, default), do: default
end
