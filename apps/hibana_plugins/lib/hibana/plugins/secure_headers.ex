defmodule Hibana.Plugins.SecureHeaders do
  @moduledoc """
  Sets standard security headers on all responses.

  ## Usage

      plug Hibana.Plugins.SecureHeaders

      # With custom options
      plug Hibana.Plugins.SecureHeaders,
        x_frame_options: "SAMEORIGIN",
        content_security_policy: "default-src 'self'; script-src 'self' 'unsafe-inline'",
        hsts: true

  ## Options

  - `:x_frame_options` - X-Frame-Options header value (default: `"DENY"`)
  - `:x_content_type_options` - X-Content-Type-Options value (default: `"nosniff"`)
  - `:referrer_policy` - Referrer-Policy value (default: `"strict-origin-when-cross-origin"`)
  - `:content_security_policy` - CSP value (default: `"default-src 'self'"`)
  - `:permissions_policy` - Permissions-Policy value (default: `nil`, not set)
  - `:hsts` - Enable Strict-Transport-Security (default: `false`; opt-in for HTTPS-only sites)
  - `:hsts_max_age` - HSTS max-age in seconds (default: `31_536_000` / 1 year)
  - `:hsts_include_subdomains` - Include subdomains in HSTS (default: `true`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      x_frame_options: Keyword.get(opts, :x_frame_options, "DENY"),
      x_content_type_options: Keyword.get(opts, :x_content_type_options, "nosniff"),
      referrer_policy: Keyword.get(opts, :referrer_policy, "strict-origin-when-cross-origin"),
      content_security_policy: Keyword.get(opts, :content_security_policy, "default-src 'self'"),
      permissions_policy: Keyword.get(opts, :permissions_policy),
      hsts: Keyword.get(opts, :hsts, false),
      hsts_max_age: Keyword.get(opts, :hsts_max_age, 31_536_000),
      hsts_include_subdomains: Keyword.get(opts, :hsts_include_subdomains, true)
    }
  end

  @impl true
  def call(conn, opts) do
    conn
    |> put_resp_header("x-frame-options", opts.x_frame_options)
    |> put_resp_header("x-content-type-options", opts.x_content_type_options)
    |> put_resp_header("x-xss-protection", "0")
    |> put_resp_header("referrer-policy", opts.referrer_policy)
    |> put_resp_header("content-security-policy", opts.content_security_policy)
    |> maybe_put_permissions_policy(opts.permissions_policy)
    |> maybe_put_hsts(opts)
  end

  defp maybe_put_permissions_policy(conn, nil), do: conn

  defp maybe_put_permissions_policy(conn, policy) do
    put_resp_header(conn, "permissions-policy", policy)
  end

  defp maybe_put_hsts(conn, %{hsts: false}), do: conn

  defp maybe_put_hsts(conn, %{hsts: true, hsts_max_age: max_age, hsts_include_subdomains: include_sub}) do
    value =
      if include_sub do
        "max-age=#{max_age}; includeSubDomains"
      else
        "max-age=#{max_age}"
      end

    put_resp_header(conn, "strict-transport-security", value)
  end
end
