defmodule BackgroundJobs do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      BackgroundJobs.Endpoint,
      Hibana.Queue
    ]

    opts = [strategy: :one_for_one, name: BackgroundJobs.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
