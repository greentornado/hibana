defmodule Hibana.Plugins.ScopedCORS do
  @moduledoc """
  Per-route CORS configuration. Apply different CORS rules to different route groups.

  ## Usage

      # In controller
      def index(conn) do
        conn = Hibana.Plugins.ScopedCORS.apply(conn,
          origins: ["https://app.example.com"],
          credentials: true
        )
        json(conn, data)
      end

      # Or as a plug with path matching
      plug Hibana.Plugins.ScopedCORS,
        rules: [
          {"/api/public/*", origins: ["*"], credentials: false},
          {"/api/admin/*", origins: ["https://admin.example.com"], credentials: true},
          {"/api/*", origins: ["https://app.example.com"]}
        ]

  ## Options

  - `:rules` - List of `{path_pattern, cors_opts}` tuples where `path_pattern` is a string with `*` wildcards and `cors_opts` is a keyword list of CORS settings (default: `[]`)
  - `:default` - Default CORS keyword options applied when no rule matches (default: `[]`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    rules =
      Keyword.get(opts, :rules, [])
      |> Enum.map(fn {pattern, cors_opts} ->
        regex =
          pattern
          |> String.replace("*", ".*")
          |> Regex.compile!()

        {regex, cors_opts}
      end)

    %{rules: rules, default: Keyword.get(opts, :default, [])}
  end

  @impl true
  def call(conn, %{rules: rules, default: default}) do
    origin = get_req_header(conn, "origin") |> List.first()

    unless origin do
      conn
    else
      cors_opts = find_matching_rule(conn.request_path, rules) || default

      if cors_opts != [] do
        apply_cors(conn, origin, cors_opts)
      else
        conn
      end
    end
  end

  @doc """
  Applies CORS headers to a connection with the given options.

  Can be called directly in a controller for per-route CORS configuration.

  ## Parameters

    - `conn` - The connection struct
    - `opts` - CORS keyword options:
      - `:origins` - List of allowed origins (default: `["*"]`)
      - `:methods` - List of allowed methods
      - `:headers` - List of allowed headers
      - `:credentials` - Whether to allow credentials (default: `false`)
      - `:max_age` - Preflight cache duration in seconds (default: `86400`)

  ## Returns

  The connection with CORS headers set.

  ## Examples

      ```elixir
      conn = Hibana.Plugins.ScopedCORS.apply(conn,
        origins: ["https://app.example.com"],
        credentials: true
      )
      ```
  """
  def apply(conn, opts) do
    origin = get_req_header(conn, "origin") |> List.first() || "*"
    apply_cors(conn, origin, opts)
  end

  defp find_matching_rule(path, rules) do
    Enum.find_value(rules, fn {regex, opts} ->
      if Regex.match?(regex, path), do: opts
    end)
  end

  defp apply_cors(conn, origin, opts) do
    origins = Keyword.get(opts, :origins, ["*"])
    methods = Keyword.get(opts, :methods, ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
    headers = Keyword.get(opts, :headers, ["Content-Type", "Authorization"])
    credentials = Keyword.get(opts, :credentials, false)
    max_age = Keyword.get(opts, :max_age, 86400)

    allowed_origin =
      if "*" in origins, do: origin, else: if(origin in origins, do: origin, else: nil)

    if allowed_origin do
      conn =
        conn
        |> put_resp_header("access-control-allow-origin", allowed_origin)
        |> put_resp_header("access-control-allow-methods", Enum.join(methods, ", "))
        |> put_resp_header("access-control-allow-headers", Enum.join(headers, ", "))
        |> put_resp_header("access-control-max-age", to_string(max_age))

      conn =
        if credentials do
          put_resp_header(conn, "access-control-allow-credentials", "true")
        else
          conn
        end

      if conn.method == "OPTIONS" do
        conn |> send_resp(204, "") |> halt()
      else
        conn
      end
    else
      conn
    end
  end
end
