defmodule Hibana.Plugins.CSRF do
  @moduledoc """
  Cross-Site Request Forgery (CSRF) protection plugin.

  Generates a CSRF token stored in the session and validates it on
  state-changing requests (POST, PUT, PATCH, DELETE).

  ## Usage

      # Requires Session plugin to be loaded first
      plug Hibana.Plugins.Session, secret: System.get_env("SECRET_KEY_BASE")
      plug Hibana.Plugins.CSRF

  ## Options

  - `:field_name` - Form field name for the CSRF token (default: `"_csrf_token"`)
  - `:header_name` - Header name for the CSRF token (default: `"x-csrf-token"`)
  - `:error_status` - HTTP status for CSRF failures (default: `403`)

  ## Skipping Validation

  Requests with `authorization` header (Bearer/API key) skip CSRF validation,
  as they don't use cookie-based sessions.

  ## Getting the Token

      token = Hibana.Plugins.CSRF.get_token(conn)
      # Use in forms: <input type="hidden" name="_csrf_token" value="\#{token}">
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      field_name: Keyword.get(opts, :field_name, "_csrf_token"),
      header_name: Keyword.get(opts, :header_name, "x-csrf-token"),
      error_status: Keyword.get(opts, :error_status, 403)
    }
  end

  @impl true
  def call(conn, opts) do
    conn = ensure_token(conn)

    if state_changing?(conn) and not api_request?(conn) do
      validate_token(conn, opts)
    else
      conn
    end
  end

  @doc """
  Gets the current CSRF token from the session, generating one if needed.

  ## Parameters

    - `conn` - The connection struct (must have session loaded)

  ## Returns

  The CSRF token string.
  """
  def get_token(conn) do
    get_session(conn, "_csrf_token") || generate_token()
  end

  defp ensure_token(conn) do
    case get_session(conn, "_csrf_token") do
      nil ->
        token = generate_token()
        put_session(conn, "_csrf_token", token)

      _token ->
        conn
    end
  end

  defp validate_token(conn, %{field_name: field, header_name: header, error_status: status}) do
    session_token = get_session(conn, "_csrf_token")

    submitted_token =
      get_token_from_params(conn, field) ||
        get_token_from_header(conn, header)

    if session_token && submitted_token && Plug.Crypto.secure_compare(session_token, submitted_token) do
      conn
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(status, Jason.encode!(%{error: "Invalid CSRF token"}))
      |> halt()
    end
  end

  defp get_token_from_params(conn, field) do
    conn = Plug.Conn.fetch_query_params(conn)
    (conn.body_params || %{}) |> Map.get(field)
  end

  defp get_token_from_header(conn, header) do
    case get_req_header(conn, header) do
      [token | _] -> token
      _ -> nil
    end
  end

  defp state_changing?(conn) do
    conn.method in ["POST", "PUT", "PATCH", "DELETE"]
  end

  defp api_request?(conn) do
    case get_req_header(conn, "authorization") do
      [_ | _] -> true
      _ -> false
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end
end
