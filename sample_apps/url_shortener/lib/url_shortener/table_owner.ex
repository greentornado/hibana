defmodule UrlShortener.TableOwner do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    :ets.new(:url_shortener_urls, [:named_table, :set, :public])
    :ets.new(:url_shortener_clicks, [:named_table, :set, :public])
    {:ok, %{}}
  end
end
