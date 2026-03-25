defmodule WebhookRelay.HookController do
  use Hibana.Controller

  @doc "POST /hooks/:channel - Receive a webhook and queue for delivery."
  def receive(conn) do
    channel = conn.params["channel"]
    payload = conn.body_params

    case WebhookRelay.EventStore.store_event(channel, payload) do
      {:ok, event} ->
        # Look up subscribers and enqueue deliveries
        subscribers = WebhookRelay.ChannelStore.get_subscriptions(channel)

        Enum.each(subscribers, fn sub ->
          WebhookRelay.DeliveryWorker.enqueue(event.id, sub)
        end)

        json(conn, %{
          ok: true,
          event_id: event.id,
          channel: channel,
          subscribers_notified: length(subscribers)
        })

      {:error, reason} ->
        put_status(conn, 500)
        |> json(%{error: "Failed to store event", reason: inspect(reason)})
    end
  end
end
