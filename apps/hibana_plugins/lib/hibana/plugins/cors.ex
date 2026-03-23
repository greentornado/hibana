defmodule Hibana.Plugins.CORS do
  @moduledoc """
  CORS (Cross-Origin Resource Sharing) plugin for Hibana.

  ## Features

  - Configurable allowed origins (including regex patterns)
  - Automatic OPTIONS handling for preflight requests
  - Support for credentials and max-age headers
  - Configurable allowed methods and headers

  ## Usage

      # Basic usage (allow all origins)
      plug Hibana.Plugins.CORS

      # With custom configuration
      plug Hibana.Plugins.CORS,
        origins: ["https://example.com", "https://app.example.com"],
        headers: ["Content-Type", "Authorization", "X-Custom-Header"],
        credentials: true,
        max_age: 86400

      # With regex pattern for origins
      plug Hibana.Plugins.CORS,
        origins: ["^https://.*\\.example\\.com$"]

  ## Options

  - `:origins` - List of allowed origins (default: `["*"]`)
  - `:methods` - Allowed HTTP methods (default: standard methods)
  - `:headers` - Allowed request headers (default: `["Content-Type", "Authorization"]`)
  - `:credentials` - Allow credentials (default: `true`)
  - `:max_age` - Preflight cache duration in seconds (default: `86400`)

  ## Response Headers

  - `access-control-allow-origin` - The allowed origin
  - `access-control-allow-methods` - Comma-separated allowed methods
  - `access-control-allow-headers` - Comma-separated allowed headers
  - `access-control-allow-credentials` - "true" if credentials allowed
  - `access-control-max-age` - Preflight cache duration
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    origins = Keyword.get(opts, :origins, ["*"])

    # Pre-compile regex patterns
    compiled_origins =
      Enum.map(origins, fn
        "^" <> _ = full_pattern -> {:regex, Regex.compile!(full_pattern)}
        other -> {:literal, other}
      end)

    %{
      origins: compiled_origins,
      methods: Keyword.get(opts, :methods, ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"]),
      headers: Keyword.get(opts, :headers, ["Content-Type", "Authorization"]),
      credentials: Keyword.get(opts, :credentials, false),
      max_age: Keyword.get(opts, :max_age, 86400)
    }
  end

  @impl true
  def call(conn, %{
        origins: origins,
        methods: methods,
        headers: headers,
        credentials: credentials,
        max_age: max_age
      }) do
    origin = get_req_header(conn, "origin") |> List.first()

    # Skip CORS if no origin header
    unless origin do
      if conn.method == "OPTIONS" do
        conn |> send_resp(204, "") |> halt()
      else
        conn
      end
    else
      if origin_allowed?(origin, origins) do
        conn =
          conn
          |> put_resp_header("access-control-allow-origin", origin)
          |> put_resp_header("access-control-allow-methods", Enum.join(methods, ", "))
          |> put_resp_header("access-control-allow-headers", Enum.join(headers, ", "))
          |> put_resp_header("access-control-max-age", to_string(max_age))
          |> then(fn c ->
            if credentials do
              put_resp_header(c, "access-control-allow-credentials", "true")
            else
              c
            end
          end)

        if conn.method == "OPTIONS" do
          conn |> send_resp(204, "") |> halt()
        else
          conn
        end
      else
        if conn.method == "OPTIONS" do
          conn |> send_resp(204, "") |> halt()
        else
          conn
        end
      end
    end
  end

  defp origin_allowed?(_origin, []), do: false

  defp origin_allowed?(origin, origins) do
    Enum.any?(origins, fn
      {:literal, "*"} -> true
      {:regex, regex} -> Regex.match?(regex, origin)
      {:literal, o} -> o == origin
    end)
  end
end
