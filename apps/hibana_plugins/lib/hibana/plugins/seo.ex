defmodule Hibana.Plugins.SEO do
  @moduledoc """
  Comprehensive SEO plugin for Hibana.

  Provides meta tags, OpenGraph, Twitter Cards, JSON-LD structured data,
  sitemap.xml generation, and robots.txt generation.

  ## Usage

      plug Hibana.Plugins.SEO,
        sitemap_urls: [...],
        robots: [allow: ["/"], disallow: ["/admin"], sitemap: "https://example.com/sitemap.xml"]

  ## In controllers

      conn
      |> SEO.meta(title: "My Page", description: "A great page")
      |> SEO.open_graph(title: "My Page", type: "website", image: "https://example.com/img.png")
      |> SEO.twitter_card(card: "summary_large_image", site: "@mysite")
      |> SEO.json_ld(%{"@context" => "https://schema.org", "@type" => "WebPage", "name" => "My Page"})

  Then in your template:

      <%= SEO.render_head(conn) %>

  ## Options

  When used as a plug, the following options control automatic serving of SEO files:

  - `:sitemap_urls` - List of URL maps for sitemap.xml generation; each map should have `:loc` (required), and optionally `:priority`, `:changefreq`, `:lastmod` (default: `[]`)
  - `:robots` - Keyword list of robots.txt options (`:user_agent`, `:allow`, `:disallow`, `:sitemap`, `:crawl_delay`) (default: `[]`)

  ## Available Functions

  - `meta/2` - Set standard meta tags (`:title`, `:description`, `:keywords`, `:canonical`, `:robots`)
  - `open_graph/2` - Set OpenGraph tags (`:title`, `:type`, `:url`, `:image`, `:description`, `:site_name`, `:locale`)
  - `twitter_card/2` - Set Twitter Card tags (`:card`, `:site`, `:creator`, `:title`, `:description`, `:image`)
  - `json_ld/2` - Add JSON-LD structured data
  - `render_head/1` - Render all SEO tags as HTML for inclusion in `<head>`
  - `generate_sitemap/1` - Generate XML sitemap from URL maps
  - `generate_robots/1` - Generate robots.txt content
  """

  use Hibana.Plugin

  import Plug.Conn

  # ── Plug callbacks ──

  @impl true
  def init(opts) do
    %{
      sitemap_urls: Keyword.get(opts, :sitemap_urls, []),
      robots: Keyword.get(opts, :robots, allow: ["/"], disallow: ["/admin"], sitemap: nil)
    }
  end

  @impl true
  def call(conn, %{sitemap_urls: sitemap_urls, robots: robots}) do
    serve_seo_files(conn, sitemap_urls: sitemap_urls, robots: robots)
  end

  # ── Meta tags ──

  @doc """
  Set standard meta tags on the connection.

  Options: :title, :description, :keywords, :canonical, :robots
  """
  def meta(conn, opts) when is_list(opts) do
    Enum.reduce(opts, conn, fn {key, value}, acc ->
      assign(acc, :"__seo_meta_#{key}", value)
    end)
  end

  # ── OpenGraph ──

  @doc """
  Set OpenGraph (og:*) tags on the connection.

  Options: :title, :type, :url, :image, :description, :site_name, :locale
  """
  def open_graph(conn, opts) when is_list(opts) do
    existing = Map.get(conn.assigns, :__seo_og, [])
    assign(conn, :__seo_og, Keyword.merge(existing, opts))
  end

  # ── Twitter Cards ──

  @doc """
  Set Twitter Card (twitter:*) tags on the connection.

  Options: :card, :site, :creator, :title, :description, :image
  """
  def twitter_card(conn, opts) when is_list(opts) do
    existing = Map.get(conn.assigns, :__seo_twitter, [])
    assign(conn, :__seo_twitter, Keyword.merge(existing, opts))
  end

  # ── JSON-LD ──

  @doc """
  Add JSON-LD structured data (schema.org) to the connection.
  Can be called multiple times to add multiple JSON-LD blocks.
  """
  def json_ld(conn, data) when is_map(data) do
    existing = Map.get(conn.assigns, :__seo_json_ld, [])
    assign(conn, :__seo_json_ld, existing ++ [data])
  end

  # ── Render head ──

  @doc """
  Render all SEO tags as an HTML string suitable for inclusion in <head>.
  """
  def render_head(conn) do
    parts = [
      render_title(conn),
      render_meta_tags(conn),
      render_canonical(conn),
      render_og_tags(conn),
      render_twitter_tags(conn),
      render_json_ld(conn)
    ]

    parts
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
  end

  # ── Sitemap generation ──

  @doc """
  Generate an XML sitemap from a list of URL maps.

  Each URL map should have: :loc (required), :priority, :changefreq, :lastmod

  ## Example

      SEO.generate_sitemap([
        %{loc: "https://example.com/", priority: 1.0, changefreq: "daily"},
        %{loc: "https://example.com/about", priority: 0.8, changefreq: "monthly"}
      ])
  """
  def generate_sitemap(urls) when is_list(urls) do
    url_entries =
      urls
      |> Enum.map(&render_sitemap_url/1)
      |> Enum.join("\n")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
    #{url_entries}
    </urlset>
    """
    |> String.trim()
  end

  # ── Robots.txt generation ──

  @doc """
  Generate robots.txt content.

  Options:
  - :user_agent - User-Agent string (default "*")
  - :allow - list of allowed paths
  - :disallow - list of disallowed paths
  - :sitemap - sitemap URL
  - :crawl_delay - crawl delay in seconds
  """
  def generate_robots(opts \\ []) do
    user_agent = Keyword.get(opts, :user_agent, "*")
    allow = Keyword.get(opts, :allow, [])
    disallow = Keyword.get(opts, :disallow, [])
    sitemap = Keyword.get(opts, :sitemap, nil)
    crawl_delay = Keyword.get(opts, :crawl_delay, nil)

    lines = ["User-agent: #{user_agent}"]

    lines = lines ++ Enum.map(allow, &"Allow: #{&1}")
    lines = lines ++ Enum.map(disallow, &"Disallow: #{&1}")

    lines =
      if crawl_delay do
        lines ++ ["Crawl-delay: #{crawl_delay}"]
      else
        lines
      end

    lines =
      if sitemap do
        lines ++ ["", "Sitemap: #{sitemap}"]
      else
        lines
      end

    Enum.join(lines, "\n")
  end

  # ── Serve SEO files plug ──

  @doc """
  Plug that serves /sitemap.xml and /robots.txt.

  Options:
  - :sitemap_urls - list of URL maps for sitemap generation
  - :robots - keyword list of robots.txt options
  """
  def serve_seo_files(conn, opts) do
    case conn.request_path do
      "/sitemap.xml" ->
        urls = Keyword.get(opts, :sitemap_urls, [])
        body = generate_sitemap(urls)

        conn
        |> put_resp_content_type("application/xml")
        |> send_resp(200, body)
        |> halt()

      "/robots.txt" ->
        robots_opts = Keyword.get(opts, :robots, [])
        body = generate_robots(robots_opts)

        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, body)
        |> halt()

      _ ->
        conn
    end
  end

  # ── Private helpers ──

  defp render_title(conn) do
    case Map.get(conn.assigns, :__seo_meta_title) do
      nil -> nil
      title -> "<title>#{escape_html(title)}</title>"
    end
  end

  defp render_meta_tags(conn) do
    meta_keys = [
      {:__seo_meta_description, "description"},
      {:__seo_meta_keywords, "keywords"},
      {:__seo_meta_robots, "robots"}
    ]

    Enum.map(meta_keys, fn {assign_key, meta_name} ->
      case Map.get(conn.assigns, assign_key) do
        nil -> nil
        value -> ~s(<meta name="#{meta_name}" content="#{escape_html(to_string(value))}">)
      end
    end)
  end

  defp render_canonical(conn) do
    case Map.get(conn.assigns, :__seo_meta_canonical) do
      nil -> nil
      url -> ~s(<link rel="canonical" href="#{escape_html(url)}">)
    end
  end

  defp render_og_tags(conn) do
    case Map.get(conn.assigns, :__seo_og) do
      nil ->
        nil

      tags ->
        Enum.map(tags, fn {key, value} ->
          ~s(<meta property="og:#{escape_html(to_string(key))}" content="#{escape_html(to_string(value))}">)
        end)
    end
  end

  defp render_twitter_tags(conn) do
    case Map.get(conn.assigns, :__seo_twitter) do
      nil ->
        nil

      tags ->
        Enum.map(tags, fn {key, value} ->
          ~s(<meta name="twitter:#{escape_html(to_string(key))}" content="#{escape_html(to_string(value))}">)
        end)
    end
  end

  defp render_json_ld(conn) do
    case Map.get(conn.assigns, :__seo_json_ld) do
      nil ->
        nil

      [] ->
        nil

      items ->
        Enum.map(items, fn data ->
          json = Jason.encode!(data) |> String.replace("</", "<\\/")
          ~s(<script type="application/ld+json">#{json}</script>)
        end)
    end
  end

  defp render_sitemap_url(url_map) do
    loc = Map.fetch!(url_map, :loc)

    children =
      [
        "  <loc>#{escape_xml(loc)}</loc>",
        optional_xml_tag("lastmod", Map.get(url_map, :lastmod)),
        optional_xml_tag("changefreq", Map.get(url_map, :changefreq)),
        optional_xml_tag("priority", Map.get(url_map, :priority))
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n")

    "  <url>\n#{children}\n  </url>"
  end

  defp optional_xml_tag(_tag, nil), do: nil

  defp optional_xml_tag(tag, value) do
    "    <#{tag}>#{escape_xml(to_string(value))}</#{tag}>"
  end

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&#39;")
  end

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
