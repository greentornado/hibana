defmodule UrlShortener.ApiController do
  use Hibana.Controller

  def shorten(conn) do
    url = conn.body_params["url"]

    if is_nil(url) or url == "" do
      conn |> Plug.Conn.put_status(400) |> json(%{error: "url is required"})
    else
      # Manual rate limiting: 30 requests per minute
      opts = Hibana.Plugins.RateLimiter.init(max_requests: 30, window_ms: 60_000)
      limited = Hibana.Plugins.RateLimiter.call(conn, opts)

      if limited.halted do
        limited
      else
        {:ok, code} = UrlShortener.Store.create(url)

        limited
        |> Plug.Conn.put_status(201)
        |> json(%{
          code: code,
          short_url: "http://localhost:4020/#{code}",
          original_url: url
        })
      end
    end
  end

  def list_urls(conn) do
    urls = UrlShortener.Store.list()
    json(conn, %{urls: urls, total: length(urls)})
  end

  def stats(conn) do
    code = conn.params["code"]

    case UrlShortener.Store.get(code) do
      {:ok, url_data} ->
        clicks = UrlShortener.Store.get_clicks(code)

        referrers =
          clicks
          |> Enum.map(& &1.referrer)
          |> Enum.reject(&is_nil/1)
          |> Enum.frequencies()

        json(conn, Map.merge(url_data, %{recent_clicks: Enum.take(clicks, 10), referrers: referrers}))

      :not_found ->
        conn |> Plug.Conn.put_status(404) |> json(%{error: "URL not found"})
    end
  end

  def delete_url(conn) do
    code = conn.params["code"]

    case UrlShortener.Store.get(code) do
      {:ok, _} ->
        UrlShortener.Store.delete(code)
        json(conn, %{deleted: true, code: code})

      :not_found ->
        conn |> Plug.Conn.put_status(404) |> json(%{error: "URL not found"})
    end
  end
end
