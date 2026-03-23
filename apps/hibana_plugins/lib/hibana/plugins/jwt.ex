defmodule Hibana.Plugins.JWT do
  @moduledoc """
  JWT (JSON Web Token) authentication plugin.

  ## Features

  - Token verification with configurable algorithms
  - Automatic token expiration checking
  - Claims extraction and assignment to conn
  - Token generation utilities

  ## Usage

      # Basic usage
      plug Hibana.Plugins.JWT, secret: "my_secret_key"

      # With custom options
      plug Hibana.Plugins.JWT,
        secret: "my_secret_key",
        algorithm: :HS256,
        header_name: "authorization",
        scheme: "Bearer"

  ## Options

  - `:secret` - Secret key for token verification (required)
  - `:algorithm` - JWT algorithm (`:HS256`, `:HS384`, `:HS512`) (default: `:HS256`)
  - `:claims` - Expected claims configuration (default: includes exp/iat)
  - `:header_name` - Header to extract token from (default: `"authorization"`)
  - `:scheme` - Auth scheme (default: `"Bearer"`)

  ## Conn Assignments

  After successful verification, these assignments are made:

  - `conn.assigns.jwt_claims` - Full JWT claims map
  - `conn.assigns.current_user` - Value of "sub" claim

  ## Module Functions

  ### sign/2-3
  Generate a new JWT token:

      claims = %{"sub" => "user123", "name" => "John"}
      token = Hibana.Plugins.JWT.sign(claims, "secret", exp: 3600)

  ### verify/2-3
  Verify and decode a token:

      {:ok, claims} = Hibana.Plugins.JWT.verify(token, "secret")

  ### decode/1
  Decode without verification (for debugging):

      {:ok, claims} = Hibana.Plugins.JWT.decode(token)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    secret = Keyword.get(opts, :secret)

    unless secret do
      raise ArgumentError, "Hibana.Plugins.JWT requires a :secret option"
    end

    %{
      secret: secret,
      algorithm: Keyword.get(opts, :algorithm, :HS256),
      claims: Keyword.get(opts, :claims, %{"exp" => true, "iat" => true}),
      header_name: Keyword.get(opts, :header_name, "authorization"),
      scheme: Keyword.get(opts, :scheme, "Bearer")
    }
  end

  @impl true
  def call(conn, %{secret: secret, algorithm: algorithm, header_name: header_name, scheme: scheme}) do
    case get_req_header(conn, header_name) do
      [token | _] ->
        case extract_token(token, scheme) do
          nil ->
            unauthorized(conn)

          token_value ->
            case verify_token(token_value, secret, algorithm) do
              {:ok, claims} ->
                conn
                |> assign(:jwt_claims, claims)
                |> assign(:current_user, claims["sub"])

              {:error, _reason} ->
                unauthorized(conn)
            end
        end

      _ ->
        unauthorized(conn)
    end
  end

  defp extract_token(header, scheme) do
    case String.split(header, " ", parts: 2) do
      [^scheme, token] -> token
      _ -> nil
    end
  end

  defp verify_token(token, secret, algorithm) do
    try do
      alg_str = algorithm_to_string(algorithm)
      jwk = JOSE.JWK.from_oct(secret)

      case JOSE.JWS.verify_strict(jwk, [alg_str], token) do
        {true, payload, _jws} ->
          claims = Jason.decode!(payload)

          case claims do
            %{"exp" => exp} when is_number(exp) ->
              now = DateTime.to_unix(DateTime.utc_now())

              if now > exp do
                {:error, :token_expired}
              else
                {:ok, claims}
              end

            _ ->
              {:ok, claims}
          end

        _ ->
          {:error, :invalid_signature}
      end
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(
      401,
      Jason.encode!(%{error: "Unauthorized", message: "Invalid or missing token"})
    )
    |> halt()
  end

  @doc """
  Generate a new JWT token.
  """
  def sign(claims, secret, opts \\ []) do
    algorithm = Keyword.get(opts, :algorithm, :HS256)
    claims = add_expiry(claims, Keyword.get(opts, :exp, 3600))

    jws = %{"alg" => algorithm_to_string(algorithm)}
    jwk = JOSE.JWK.from_oct(secret)
    jwt = %JOSE.JWT{fields: claims}

    {_, signed} = JOSE.JWT.sign(jwk, jws, jwt) |> JOSE.JWS.compact()
    signed
  end

  @doc """
  Verify and decode a JWT token.
  """
  def verify(token, secret, _opts \\ []) do
    verify_token(token, secret, :HS256)
  end

  @doc """
  Extract claims from a token without verification (for debugging).
  """
  def decode(token) do
    try do
      %JOSE.JWT{fields: fields} = JOSE.JWT.peek(token)
      {:ok, fields}
    rescue
      _ -> {:error, :invalid_token}
    end
  end

  defp add_expiry(claims, exp) when is_integer(exp) do
    now = DateTime.to_unix(DateTime.utc_now())

    Map.put(claims, "exp", now + exp)
    |> Map.put("iat", now)
  end

  defp add_expiry(claims, _), do: claims

  defp algorithm_to_string(:HS256), do: "HS256"
  defp algorithm_to_string(:HS384), do: "HS384"
  defp algorithm_to_string(:HS512), do: "HS512"
end
