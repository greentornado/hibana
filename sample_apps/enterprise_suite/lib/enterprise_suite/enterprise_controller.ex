defmodule EnterpriseSuite.EnterpriseController do
  @moduledoc """
  Main controller for enterprise suite demo.
  """
  use Hibana.Controller

  def index(conn, _params) do
    json(conn, %{
      app: "EnterpriseSuite",
      description: "Full enterprise feature demonstration",
      features: [
        "Admin Dashboard - Auto-generated CRUD interface",
        "I18n - Multi-language support (EN/VI/JA)",
        "SEO - Meta tags, sitemap.xml, robots.txt",
        "TOTP - 2FA with QR codes",
        "API Versioning - v1/v2 endpoints"
      ],
      endpoints: [
        %{method: "GET", path: "/admin", description: "Auto-generated admin dashboard"},
        %{method: "GET", path: "/i18n/:locale", description: "Switch locale"},
        %{method: "GET", path: "/i18n/demo", description: "Translation examples"},
        %{method: "GET", path: "/sitemap.xml", description: "SEO sitemap"},
        %{method: "GET", path: "/robots.txt", description: "SEO robots file"},
        %{method: "POST", path: "/auth/register", description: "User registration"},
        %{method: "POST", path: "/auth/2fa/setup", description: "Setup 2FA"},
        %{method: "GET", path: "/api/users", description: "API v1 users"},
        %{method: "GET", path: "/v2/api/users", description: "API v2 users"}
      ],
      enterprise_ready: true
    })
  end

  def features(conn, _params) do
    json(conn, %{
      admin: %{
        description: "Auto-generated CRUD admin dashboard",
        models: ["User", "Product", "Order"],
        features: ["List", "Create", "Edit", "Delete", "Search", "Filter"]
      },
      i18n: %{
        description: "Internationalization with 3 locales",
        locales: [
          %{code: "en", name: "English", flag: "🇺🇸"},
          %{code: "vi", name: "Vietnamese", flag: "🇻🇳"},
          %{code: "ja", name: "Japanese", flag: "🇯🇵"}
        ]
      },
      seo: %{
        description: "Search engine optimization",
        features: ["Meta tags", "OpenGraph", "Sitemap", "Robots.txt"]
      },
      totp: %{
        description: "Time-based One-Time Password 2FA",
        features: ["QR Code setup", "Google Authenticator compatible", "Backup codes"]
      },
      api_versioning: %{
        description: "API version management",
        versions: ["v1", "v2"],
        strategy: "Path-based"
      }
    })
  end

  def admin_redirect(conn, _params) do
    redirect(conn, "/admin/dashboard")
  end
end
