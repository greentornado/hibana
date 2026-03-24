# `Hibana.Plugins.SEO`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/seo.ex#L1)

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

# `before_send`

# `generate_robots`

Generate robots.txt content.

Options:
- :user_agent - User-Agent string (default "*")
- :allow - list of allowed paths
- :disallow - list of disallowed paths
- :sitemap - sitemap URL
- :crawl_delay - crawl delay in seconds

# `generate_sitemap`

Generate an XML sitemap from a list of URL maps.

Each URL map should have: :loc (required), :priority, :changefreq, :lastmod

## Example

    SEO.generate_sitemap([
      %{loc: "https://example.com/", priority: 1.0, changefreq: "daily"},
      %{loc: "https://example.com/about", priority: 0.8, changefreq: "monthly"}
    ])

# `json_ld`

Add JSON-LD structured data (schema.org) to the connection.
Can be called multiple times to add multiple JSON-LD blocks.

# `meta`

Set standard meta tags on the connection.

Options: :title, :description, :keywords, :canonical, :robots

# `open_graph`

Set OpenGraph (og:*) tags on the connection.

Options: :title, :type, :url, :image, :description, :site_name, :locale

# `render_head`

Render all SEO tags as an HTML string suitable for inclusion in <head>.

# `serve_seo_files`

Plug that serves /sitemap.xml and /robots.txt.

Options:
- :sitemap_urls - list of URL maps for sitemap generation
- :robots - keyword list of robots.txt options

# `start_link`

# `twitter_card`

Set Twitter Card (twitter:*) tags on the connection.

Options: :card, :site, :creator, :title, :description, :image

---

*Consult [api-reference.md](api-reference.md) for complete listing*
