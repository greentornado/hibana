defmodule TelegramBot.TableOwner do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:telegram_messages, [:named_table, :ordered_set, :public])
    {:ok, %{}}
  end
end
