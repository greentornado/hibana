defmodule UrlShortener do
  use Application

  @impl true
  def start(_type, _args) do
    # Init ETS tables
    :ets.new(:url_shortener_urls, [:named_table, :set, :public])
    :ets.new(:url_shortener_clicks, [:named_table, :set, :public])

    # Seed example URLs
    seed_data()

    children = [
      UrlShortener.Endpoint
    ]

    opts = [strategy: :one_for_one, name: UrlShortener.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp seed_data do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    [
      {"elixir", "https://elixir-lang.org", now, 42, now},
      {"github", "https://github.com", now, 128, now},
      {"hibana", "https://hex.pm/packages/hibana", now, 7, now}
    ]
    |> Enum.each(fn {code, url, created, clicks, last} ->
      :ets.insert(:url_shortener_urls, {code, url, created, clicks, last})
      :ets.insert(:url_shortener_clicks, {code, []})
    end)
  end
end
