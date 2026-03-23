defmodule Hibana.Plugins.Session do
  @moduledoc """
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
  """

  use Hibana.Plugin
  import Plug.Conn
  alias Plug.Crypto

  @impl true
  def init(opts) do
    secret = Keyword.get(opts, :secret)

    unless secret && byte_size(secret) >= 32 do
      raise ArgumentError,
            "Hibana.Plugins.Session requires a :secret option of at least 32 bytes"
    end

    %{
      store: Keyword.get(opts, :store, :cookie),
      key: Keyword.get(opts, :key, "hibana_session"),
      secret: secret,
      max_age: Keyword.get(opts, :max_age, 86400 * 30)
    }
  end

  @impl true
  def call(conn, %{key: key, secret: secret, max_age: max_age}) do
    session_data = fetch_session(conn, key, secret)
    conn = %{conn | assigns: Map.merge(conn.assigns, %{__session__: session_data})}
    register_before_send(conn, fn c -> persist_session(c, key, secret, max_age) end)
  end

  defp fetch_session(conn, key, secret) do
    case get_req_cookie(conn, key) do
      nil ->
        %{}

      value ->
        case Crypto.decrypt(secret, key, value) do
          {:ok, data} ->
            :erlang.binary_to_term(data, [:safe])

          _ ->
            %{}
        end
    end
  end

  defp persist_session(conn, key, secret, max_age) do
    session_data = Map.get(conn.assigns, :__session__, %{})

    if map_size(session_data) > 0 do
      encrypted = Crypto.encrypt(secret, key, :erlang.term_to_binary(session_data))

      conn
      |> put_resp_cookie(key, encrypted,
        http_only: true,
        secure: true,
        same_site: "Lax",
        max_age: max_age,
        path: "/"
      )
    else
      conn
      |> delete_resp_cookie(key, path: "/")
    end
  end

  defp get_req_cookie(conn, key) do
    case get_req_header(conn, "cookie") do
      [cookie_string | _] ->
        cookie_string
        |> String.split("; ")
        |> Enum.find_value(fn cookie ->
          case String.split(cookie, "=", parts: 2) do
            [^key, value] -> value
            _ -> nil
          end
        end)

      _ ->
        nil
    end
  end
end
