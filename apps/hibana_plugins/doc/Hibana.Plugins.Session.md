# `Hibana.Plugins.Session`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/session.ex#L1)

Session management plugin using encrypted cookies.

## Features

- Cookie-based session storage
- Automatic encryption/decryption
- Plug-and-play session access
- Automatic session persistence on response

## Usage

    # Basic usage
    plug Hibana.Plugins.Session

    # With custom configuration
    plug Hibana.Plugins.Session,
      key: "my_app_session",
      secret: "your-secret-key-at-least-64-bytes",
      max_age: 86400 * 7  # 7 days

## Options

- `:store` - Storage type (default: `:cookie`)
- `:key` - Cookie name (default: `"hibana_session"`)
- `:secret` - Encryption secret (default: `"secret_key_for_session"`)
- `:max_age` - Session lifetime in seconds (default: `86400 * 30`)

## Session Access

Use `get_session/2` and `put_session/3` in controllers:

    defmodule MyController do
      use Hibana.Controller

      def login(conn) do
        # Store in session
        put_session(conn, :user_id, user.id)
        |> redirect(to: "/dashboard")
      end

      def dashboard(conn) do
        # Read from session
        user_id = get_session(conn, :user_id)
        # ...
      end
    end

## Implementation

Sessions are stored in `conn.assigns.__session__` and automatically
persisted to cookies on response via `register_before_send/2`.

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
