defmodule Hibana.Plugins.SEOTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.SEO

  describe "meta/2" do
    test "sets title and description as assigns" do
      conn =
        Plug.Test.conn(:get, "/")
        |> SEO.meta(title: "My Page", description: "A great page")

      assert conn.assigns[:__seo_meta_title] == "My Page"
      assert conn.assigns[:__seo_meta_description] == "A great page"
    end
  end

  describe "render_head/1" do
    test "produces HTML with title and description" do
      conn =
        Plug.Test.conn(:get, "/")
        |> SEO.meta(title: "Test Title", description: "Test Desc")

      html = SEO.render_head(conn)
      assert html =~ "<title>Test Title</title>"
      assert html =~ ~s(<meta name="description" content="Test Desc">)
    end

    test "includes canonical link when set" do
      conn =
        Plug.Test.conn(:get, "/")
        |> SEO.meta(canonical: "https://example.com/page")

      html = SEO.render_head(conn)
      assert html =~ ~s(rel="canonical")
      assert html =~ "https://example.com/page"
    end

    test "renders OpenGraph tags" do
      conn =
        Plug.Test.conn(:get, "/")
        |> SEO.open_graph(title: "OG Title", type: "website")

      html = SEO.render_head(conn)
      assert html =~ ~s(property="og:title")
      assert html =~ ~s(content="OG Title")
    end

    test "renders Twitter card tags" do
      conn =
        Plug.Test.conn(:get, "/")
        |> SEO.twitter_card(card: "summary", site: "@mysite")

      html = SEO.render_head(conn)
      assert html =~ ~s(name="twitter:card")
      assert html =~ ~s(content="summary")
    end
  end

  describe "generate_sitemap/1" do
    test "produces valid XML with URLs" do
      xml =
        SEO.generate_sitemap([
          %{loc: "https://example.com/", priority: 1.0, changefreq: "daily"},
          %{loc: "https://example.com/about", priority: 0.8}
        ])

      assert xml =~ ~s(<?xml version="1.0")
      assert xml =~ "<urlset"
      assert xml =~ "<loc>https://example.com/</loc>"
      assert xml =~ "<priority>1.0</priority>"
      assert xml =~ "<changefreq>daily</changefreq>"
      assert xml =~ "<loc>https://example.com/about</loc>"
    end
  end

  describe "generate_robots/1" do
    test "produces robots.txt text" do
      text =
        SEO.generate_robots(
          allow: ["/"],
          disallow: ["/admin"],
          sitemap: "https://example.com/sitemap.xml"
        )

      assert text =~ "User-agent: *"
      assert text =~ "Allow: /"
      assert text =~ "Disallow: /admin"
      assert text =~ "Sitemap: https://example.com/sitemap.xml"
    end

    test "defaults to wildcard user-agent" do
      text = SEO.generate_robots([])
      assert text =~ "User-agent: *"
    end
  end
end
