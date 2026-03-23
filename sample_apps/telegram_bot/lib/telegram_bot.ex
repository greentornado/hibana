defmodule TelegramBot do
  use Application

  @moduledoc """
  Telegram Bot sample app for the Hibana framework.
  Receives messages via webhook and responds using the Telegram Bot API.
  """

  def start(_type, _args) do
    TelegramBot.MessageLog.init()

    children = [
      TelegramBot.Endpoint
    ]

    opts = [strategy: :one_for_one, name: TelegramBot.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
