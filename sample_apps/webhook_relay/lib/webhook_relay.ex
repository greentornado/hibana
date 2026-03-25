defmodule WebhookRelay do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WebhookRelay.ChannelStore,
      WebhookRelay.EventStore,
      WebhookRelay.DeliveryWorker,
      WebhookRelay.Endpoint
    ]

    opts = [strategy: :one_for_one, name: WebhookRelay.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
