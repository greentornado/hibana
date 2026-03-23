defmodule Hibana.Plugins.APIKey do
  @moduledoc """
  API key authentication plugin. Supports header, query param, or bearer token.

  ## Usage

      plug Hibana.Plugins.APIKey,
        keys: ["sk_live_abc123", "sk_live_def456"],
        header: "x-api-key"

      # Or with a validator function
      plug Hibana.Plugins.APIKey,
        validator: &MyApp.Auth.validate_api_key/1,
        sources: [:header, :query]

  ## Options

  - `:keys` - List of valid API key strings for static validation (default: `[]`)
  - `:validator` - A function `(String.t() -> boolean())` for custom key validation; takes precedence over `:keys` (default: `nil`)
  - `:header` - Request header name to extract the API key from (default: `"x-api-key"`)
  - `:query_param` - Query parameter name to extract the API key from (default: `"api_key"`)
  - `:sources` - List of sources to check for the API key, in order; valid values are `:header`, `:query`, and `:bearer` (default: `[:header, :query, :bearer]`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      keys: Keyword.get(opts, :keys, []),
      validator: Keyword.get(opts, :validator),
      header: Keyword.get(opts, :header, "x-api-key"),
      query_param: Keyword.get(opts, :query_param, "api_key"),
      sources: Keyword.get(opts, :sources, [:header, :query, :bearer])
    }
  end

  @impl true
  def call(conn, opts) do
    conn = Plug.Conn.fetch_query_params(conn)

    case extract_key(conn, opts) do
      nil ->
        unauthorized(conn, "Missing API key")

      key ->
        if validate_key(key, opts) do
          assign(conn, :api_key, key)
        else
          unauthorized(conn, "Invalid API key")
        end
    end
  end

  defp extract_key(conn, opts) do
    Enum.find_value(opts.sources, fn
      :header ->
        case get_req_header(conn, opts.header) do
          [key | _] -> key
          _ -> nil
        end

      :query ->
        conn.query_params[opts.query_param]

      :bearer ->
        case get_req_header(conn, "authorization") do
          ["Bearer " <> key | _] -> key
          _ -> nil
        end
    end)
  end

  defp validate_key(key, %{validator: validator}) when is_function(validator) do
    validator.(key)
  end

  defp validate_key(key, %{keys: keys}) when is_list(keys) and keys != [] do
    # Constant-time comparison to prevent timing attacks
    Enum.any?(keys, fn valid_key ->
      Plug.Crypto.secure_compare(key, valid_key)
    end)
  end

  defp validate_key(_, _), do: false

  defp unauthorized(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: "Unauthorized", message: message}))
    |> halt()
  end
end
