defmodule EnterpriseSuite.Endpoint do
  @moduledoc """
  Endpoint with enterprise plugins: Admin, I18n, SEO, TOTP.
  """
  use Hibana.Endpoint, otp_app: :enterprise_suite

  plug Hibana.Plugins.RequestId
  plug Hibana.Plugins.Logger

  # Enterprise plugins
  plug Hibana.Plugins.I18n, default_locale: "en", locales: ["en", "vi", "ja"]

  plug Hibana.Plugins.SEO,
    title: "Enterprise Suite Demo",
    description: "Full-featured enterprise application with Admin, I18n, SEO, TOTP",
    keywords: ["hibana", "elixir", "enterprise", "admin", "i18n", "totp"]

  plug Hibana.Plugins.Admin,
    models: [EnterpriseSuite.User, EnterpriseSuite.Product, EnterpriseSuite.Order]

  plug Hibana.Plugins.APIVersioning, default: "v1", versions: ["v1", "v2"]

  plug EnterpriseSuite.Router
end
