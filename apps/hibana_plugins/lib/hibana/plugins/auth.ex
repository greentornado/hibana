defmodule Hibana.Plugins.Auth do
  @moduledoc """
  HTTP Basic authentication plugin.

  ## Features

  - RFC 7617 compliant Basic Auth
  - Customizable realm name
  - Pluggable validator function
  - Automatic 401 response with WWW-Authenticate header

  ## Usage

      # Basic usage with default realm
      plug Hibana.Plugins.Auth

      # With custom realm
      plug Hibana.Plugins.Auth, realm: "Admin Area"

      # With custom validator
      plug Hibana.Plugins.Auth,
        validator: fn username, password ->
          username == "admin" && password == "secret"
        end

  ## Options

  - `:realm` - Authentication realm name (default: `"Restricted"`)
  - `:validator` - Custom validation function (default: always returns `false`)

  ## Validator Function

  The validator receives username and password:

      validator = fn username, password ->
        # Check against database, LDAP, etc.
        username == "admin" && password == "secret"
      end

  ## Conn Assignments

  On successful authentication:

      conn.assigns.current_user  # => "username"

  ## Response

  On failed authentication:

      HTTP 401 Unauthorized
      WWW-Authenticate: Basic realm="Protected Area"
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      realm: Keyword.get(opts, :realm, "Restricted"),
      validator: Keyword.get(opts, :validator, &default_validator/2)
    }
  end

  @impl true
  def call(conn, %{realm: realm, validator: validator}) do
    case get_req_header(conn, "authorization") do
      ["Basic " <> encoded | _] ->
        case Base.decode64(encoded) do
          {:ok, decoded} ->
            case String.split(decoded, ":", parts: 2) do
              [username, password] ->
                if validator.(username, password) do
                  assign(conn, :current_user, username)
                else
                  unauthorized(conn, realm)
                end

              _ ->
                unauthorized(conn, realm)
            end

          _ ->
            unauthorized(conn, realm)
        end

      _ ->
        unauthorized(conn, realm)
    end
  end

  defp default_validator(_username, _password), do: false

  defp unauthorized(conn, realm) do
    conn
    |> put_resp_header("www-authenticate", "Basic realm=\"#{realm}\"")
    |> send_resp(401, "Unauthorized")
    |> halt()
  end
end
