defmodule UrlShortener.Store do
  @urls_table :url_shortener_urls
  @clicks_table :url_shortener_clicks

  def create(url) do
    code = generate_code()
    now = DateTime.utc_now() |> DateTime.to_iso8601()
    :ets.insert(@urls_table, {code, url, now, 0, nil})
    :ets.insert(@clicks_table, {code, []})
    {:ok, code}
  end

  def get(code) do
    case :ets.lookup(@urls_table, code) do
      [{^code, url, created, clicks, last_clicked}] ->
        {:ok, %{code: code, url: url, created_at: created, click_count: clicks, last_clicked_at: last_clicked}}

      [] ->
        :not_found
    end
  end

  def list do
    :ets.tab2list(@urls_table)
    |> Enum.map(fn {code, url, created, clicks, last} ->
      %{code: code, url: url, created_at: created, click_count: clicks, last_clicked_at: last}
    end)
    |> Enum.sort_by(& &1.created_at, :desc)
  end

  def delete(code) do
    :ets.delete(@urls_table, code)
    :ets.delete(@clicks_table, code)
    :ok
  end

  def record_click(code, referrer, user_agent) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    # Increment click count and update last_clicked
    case :ets.lookup(@urls_table, code) do
      [{^code, url, created, clicks, _last}] ->
        :ets.insert(@urls_table, {code, url, created, clicks + 1, now})
      _ ->
        :ok
    end

    # Record click detail (keep last 100)
    case :ets.lookup(@clicks_table, code) do
      [{^code, clicks}] ->
        click = %{timestamp: now, referrer: referrer, user_agent: user_agent}
        :ets.insert(@clicks_table, {code, Enum.take([click | clicks], 100)})
      _ ->
        :ok
    end
  end

  def get_clicks(code) do
    case :ets.lookup(@clicks_table, code) do
      [{^code, clicks}] -> clicks
      [] -> []
    end
  end

  defp generate_code do
    :crypto.strong_rand_bytes(4)
    |> Base.url_encode64(padding: false)
    |> binary_part(0, 6)
  end
end
