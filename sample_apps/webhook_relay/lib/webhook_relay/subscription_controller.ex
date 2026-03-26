defmodule WebhookRelay.SubscriptionController do
  use Hibana.Controller

  @doc "GET /api/subscriptions - List all subscriptions."
  def index(conn) do
    subscriptions = WebhookRelay.ChannelStore.all_subscriptions()
    json(conn, %{subscriptions: subscriptions, total: length(subscriptions)})
  end

  @doc "POST /api/subscriptions - Create a new subscription."
  def create(conn) do
    body = conn.body_params
    channel = Map.get(body, "channel")
    url = Map.get(body, "url")
    secret = Map.get(body, "secret", "")

    cond do
      is_nil(channel) or channel == "" ->
        put_status(conn, 422)
        |> json(%{error: "channel is required"})

      is_nil(url) or url == "" ->
        put_status(conn, 422)
        |> json(%{error: "url is required"})

      true ->
        {:ok, subscription} = WebhookRelay.ChannelStore.subscribe(channel, url, secret)

        put_status(conn, 201)
        |> json(%{subscription: subscription})
    end
  end

  @doc "DELETE /api/subscriptions/:id - Delete a subscription."
  def delete(conn) do
    id = conn.params["id"]

    case WebhookRelay.ChannelStore.find(id) do
      nil ->
        put_status(conn, 404)
        |> json(%{error: "Subscription not found"})

      _sub ->
        WebhookRelay.ChannelStore.delete(id)
        json(conn, %{ok: true, message: "Subscription deleted"})
    end
  end
end
