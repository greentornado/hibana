defmodule Hibana.Plugins.OAuth do
  @moduledoc """
  OAuth 2.0 authorization plugin supporting multiple providers.

  ## Supported Providers

  - Google OAuth 2.0
  - GitHub OAuth
  - Facebook OAuth

  ## Usage

      # Google OAuth
      plug Hibana.Plugins.OAuth,
        provider: :google,
        client_id: "your_client_id",
        client_secret: "your_client_secret",
        redirect_uri: "http://localhost:4000/auth/callback"

      # GitHub OAuth
      plug Hibana.Plugins.OAuth,
        provider: :github,
        client_id: "your_client_id",
        client_secret: "your_client_secret",
        redirect_uri: "http://localhost:4000/auth/callback"

  ## Routes

  The plugin handles these routes automatically:

  - `GET /auth/login` - Initiates OAuth flow
  - `GET /auth/callback` - Handles OAuth callback

  ## Flow

  1. User visits `/auth/login`
  2. Redirected to provider's authorization page
  3. User grants permission
  4. Redirect back to `/auth/callback`
  5. Plugin exchanges code for token
  6. Fetches user info from provider
  7. Generates JWT and sets cookie
  8. Redirects to `/`

  ## Options

  - `:provider` - OAuth provider (`:google`, `:github`, `:facebook`)
  - `:client_id` - OAuth client ID
  - `:client_secret` - OAuth client secret
  - `:redirect_uri` - Callback URL
  - `:scope` - OAuth scope (optional, uses provider defaults)
  - `:jwt_secret` - Secret for generated JWT (required)

  ## Module Functions

  ### authorization_url/2
  Generate authorization URL:

      url = Hibana.Plugins.OAuth.authorization_url(:google, client_id: "...", redirect_uri: "...")

  ### exchange_token/2
  Exchange authorization code for access token:

      {:ok, token_data} = Hibana.Plugins.OAuth.exchange_token(code, config)

  ### fetch_user/2
  Fetch user profile from provider:

      {:ok, user} = Hibana.Plugins.OAuth.fetch_user(access_token, user_url)
  """

  use Hibana.Plugin
  import Plug.Conn
  # JWT is used for signing tokens in handle_callback

  def redirect(conn, to: url) do
    conn
    |> put_resp_header("location", url)
    |> send_resp(302, "")
    |> halt()
  end

  @providers %{
    google: %{
      auth_url: "https://accounts.google.com/o/oauth2/v2/auth",
      token_url: "https://oauth2.googleapis.com/token",
      user_url: "https://www.googleapis.com/oauth2/v2/userinfo",
      scope: "openid email profile"
    },
    github: %{
      auth_url: "https://github.com/login/oauth/authorize",
      token_url: "https://github.com/login/oauth/access_token",
      user_url: "https://api.github.com/user",
      scope: "user:email"
    },
    facebook: %{
      auth_url: "https://www.facebook.com/v12.0/dialog/oauth",
      token_url: "https://graph.facebook.com/v12.0/oauth/access_token",
      user_url: "https://graph.facebook.com/me",
      scope: "email,public_profile"
    }
  }

  @impl true
  def init(opts) do
    provider = Keyword.get(opts, :provider)
    config = @providers[provider]

    jwt_secret = Keyword.get(opts, :jwt_secret)

    unless jwt_secret do
      raise ArgumentError,
            "Hibana.Plugins.OAuth requires a :jwt_secret option"
    end

    %{
      provider: provider,
      client_id: Keyword.get(opts, :client_id),
      client_secret: Keyword.get(opts, :client_secret),
      redirect_uri: Keyword.get(opts, :redirect_uri),
      scope: Keyword.get(opts, :scope, config[:scope]),
      auth_url: config[:auth_url],
      token_url: config[:token_url],
      user_url: config[:user_url],
      jwt_secret: jwt_secret
    }
  end

  @impl true
  def call(conn, config) do
    case conn.path_info do
      ["auth", "login"] ->
        {conn, url} = authorization_url(conn, config)
        redirect(conn, to: url)

      ["auth", "callback"] ->
        handle_callback(conn, config)

      _ ->
        conn
    end
  end

  defp authorization_url(conn, config) do
    state = generate_state()

    params = [
      client_id: config.client_id,
      redirect_uri: config.redirect_uri,
      response_type: "code",
      scope: config.scope,
      state: state
    ]

    # Store state in cookie for CSRF validation on callback
    conn =
      put_resp_cookie(conn, "_oauth_state", state,
        http_only: true,
        max_age: 600,
        path: "/",
        secure: true,
        same_site: "Lax"
      )

    query_string = URI.encode_query(params)
    {conn, "#{config.auth_url}?#{query_string}"}
  end

  defp handle_callback(conn, %{
         client_id: client_id,
         client_secret: client_secret,
         redirect_uri: redirect_uri,
         token_url: token_url,
         user_url: user_url,
         jwt_secret: jwt_secret
       }) do
    conn = Plug.Conn.fetch_query_params(conn)
    code = conn.query_params["code"]
    state = conn.query_params["state"]
    stored_state = get_oauth_state_cookie(conn)

    if code && state && state == stored_state do
      case exchange_code_for_token(code, client_id, client_secret, redirect_uri, token_url) do
        {:ok, token_data} ->
          access_token = token_data["access_token"]

          case fetch_user_info(access_token, user_url) do
            {:ok, user} ->
              jwt_token =
                Hibana.Plugins.JWT.sign(
                  %{
                    "sub" => user["id"] || user["email"],
                    "email" => user["email"],
                    "name" => user["name"],
                    "provider" => "oauth"
                  },
                  jwt_secret,
                  exp: 86400 * 7
                )

              conn
              |> put_resp_cookie("token", jwt_token,
                http_only: true,
                secure: true,
                same_site: "Lax",
                max_age: 86400 * 7,
                path: "/"
              )
              |> delete_resp_cookie("_oauth_state", path: "/")
              |> redirect(to: "/")

            {:error, _} ->
              error(conn, "Failed to fetch user info")
          end

        {:error, _} ->
          error(conn, "Failed to exchange code for token")
      end
    else
      error(conn, "Missing authorization code")
    end
  end

  defp exchange_code_for_token(code, client_id, client_secret, redirect_uri, token_url) do
    body =
      URI.encode_query(
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri,
        grant_type: "authorization_code"
      )

    case :hackney.post(
           token_url,
           [{"Content-Type", "application/x-www-form-urlencoded"}],
           body,
           with_body: true
         ) do
      {:ok, 200, _headers, response} ->
        {:ok, Jason.decode!(response)}

      _ ->
        {:error, :token_exchange_failed}
    end
  end

  defp fetch_user_info(access_token, user_url) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case :hackney.get(user_url, headers, "", with_body: true) do
      {:ok, 200, _headers, response} ->
        {:ok, Jason.decode!(response)}

      _ ->
        {:error, :fetch_user_failed}
    end
  end

  defp get_oauth_state_cookie(conn) do
    case Plug.Conn.get_req_header(conn, "cookie") do
      [cookie_string | _] ->
        cookie_string
        |> String.split("; ")
        |> Enum.find_value(fn cookie ->
          case String.split(cookie, "=", parts: 2) do
            ["_oauth_state", value] -> value
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end

  defp generate_state do
    :crypto.strong_rand_bytes(16) |> Base.encode64()
  end

  defp error(conn, message) do
    escaped = Plug.HTML.html_escape(message)

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(400, "<html><body><h1>OAuth Error</h1><p>#{escaped}</p></body></html>")
    |> halt()
  end

  @doc """
  Generate OAuth authorization URL for a provider.
  """
  def generate_authorization_url(provider, config) do
    provider_config = @providers[provider]

    params = [
      client_id: config[:client_id],
      redirect_uri: config[:redirect_uri],
      response_type: "code",
      scope: config[:scope] || provider_config[:scope],
      state: generate_state()
    ]

    query_string = URI.encode_query(params)
    "#{provider_config[:auth_url]}?#{query_string}"
  end

  @doc """
  Exchange authorization code for access token.
  """
  def exchange_token(code, config) do
    body =
      URI.encode_query(
        client_id: config[:client_id],
        client_secret: config[:client_secret],
        code: code,
        redirect_uri: config[:redirect_uri],
        grant_type: "authorization_code"
      )

    :hackney.post(
      config[:token_url],
      [{"Content-Type", "application/x-www-form-urlencoded"}],
      body,
      with_body: true
    )
    |> parse_token_response()
  end

  @doc """
  Fetch user profile from provider.
  """
  def fetch_user(access_token, user_url) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    :hackney.get(user_url, headers, "", with_body: true)
    |> parse_user_response()
  end

  defp parse_token_response({:ok, 200, _headers, response}) do
    {:ok, Jason.decode!(response)}
  rescue
    _ -> {:error, :invalid_response}
  end

  defp parse_token_response(_), do: {:error, :token_exchange_failed}

  defp parse_user_response({:ok, 200, _headers, response}) do
    {:ok, Jason.decode!(response)}
  rescue
    _ -> {:error, :invalid_response}
  end

  defp parse_user_response(_), do: {:error, :fetch_failed}
end
