defmodule TelegramBot do
  use Application

  @moduledoc """
  Telegram Bot sample app for the Hibana framework.
  Receives messages via webhook and responds using the Telegram Bot API.
  """

  @impl true
  def start(_type, _args) do
    children = [
      TelegramBot.TableOwner,
      TelegramBot.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TelegramBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
