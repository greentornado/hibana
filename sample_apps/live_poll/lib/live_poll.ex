defmodule LivePoll do
  use Application

  def start(_type, _args) do
    children = [
      LivePoll.PollNotifier,
      LivePoll.PollStore,
      LivePoll.Endpoint
    ]

    opts = [strategy: :one_for_one, name: LivePoll.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
