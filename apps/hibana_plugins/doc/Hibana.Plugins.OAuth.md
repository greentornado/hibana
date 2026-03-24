# `Hibana.Plugins.OAuth`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/oauth.ex#L1)

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

# `before_send`

# `exchange_token`

Exchange authorization code for access token.

# `fetch_user`

Fetch user profile from provider.

# `generate_authorization_url`

Generate OAuth authorization URL for a provider.

# `redirect`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
