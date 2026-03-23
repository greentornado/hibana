defmodule Hibana.Plugins.RequestSigning do
  @moduledoc """
  HMAC request signing plugin for API-to-API authentication.

  ## As a Plug (verify incoming requests)

      plug Hibana.Plugins.RequestSigning,
        secret: "my-shared-secret",
        max_age: 300

  ## Signing outgoing requests

      headers = Hibana.Plugins.RequestSigning.sign_headers(
        method: "POST",
        path: "/api/data",
        body: ~s({"key":"value"}),
        secret: "my-shared-secret"
      )

  ## Options

  - `:secret` - Shared secret key used for HMAC signing (required)
  - `:max_age` - Maximum allowed age of a request signature in seconds (default: `300`)
  - `:algorithm` - Hash algorithm for HMAC computation (default: `:sha256`)
  """

  @behaviour Plug

  @default_max_age 300
  @signature_header "x-signature"
  @timestamp_header "x-timestamp"
  @algorithm :sha256

  @impl true
  def init(opts) do
    unless Keyword.has_key?(opts, :secret) do
      raise ArgumentError, "RequestSigning requires :secret option"
    end

    opts
    |> Keyword.put_new(:max_age, @default_max_age)
    |> Keyword.put_new(:algorithm, @algorithm)
  end

  @impl true
  def call(conn, opts) do
    secret = Keyword.fetch!(opts, :secret)
    max_age = Keyword.get(opts, :max_age, @default_max_age)
    algorithm = Keyword.get(opts, :algorithm, @algorithm)

    with {:ok, signature} <- get_header(conn, @signature_header),
         {:ok, timestamp_str} <- get_header(conn, @timestamp_header),
         {:ok, timestamp} <- parse_timestamp(timestamp_str),
         :ok <- validate_timestamp(timestamp, max_age),
         {:ok, body} <- read_body_cached(conn),
         expected <-
           compute_signature(
             conn.method,
             conn.request_path,
             timestamp_str,
             body,
             secret,
             algorithm
           ),
         true <- Plug.Crypto.secure_compare(expected, signature) do
      conn
      |> Plug.Conn.assign(:request_verified, true)
      |> Plug.Conn.assign(:request_timestamp, timestamp)
    else
      _ ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(
          401,
          Jason.encode!(%{error: "Invalid or missing request signature"})
        )
        |> Plug.Conn.halt()
    end
  end

  @doc """
  Sign request parameters and return the signature string.

  ## Options
    - `:method` - HTTP method (required)
    - `:path` - request path (required)
    - `:body` - request body (default: "")
    - `:secret` - shared secret (required)
    - `:timestamp` - override timestamp (default: current time)
    - `:algorithm` - hash algorithm (default: :sha256)
  """
  def sign(opts) do
    method = opts |> Keyword.fetch!(:method) |> String.upcase()
    path = Keyword.fetch!(opts, :path)
    body = Keyword.get(opts, :body, "")
    secret = Keyword.fetch!(opts, :secret)
    timestamp = Keyword.get(opts, :timestamp, to_string(System.os_time(:second)))
    algorithm = Keyword.get(opts, :algorithm, @algorithm)

    compute_signature(method, path, to_string(timestamp), body, secret, algorithm)
  end

  @doc """
  Generate signature headers for an outgoing request.
  Returns a list of `{header_name, value}` tuples.

  ## Options
    - `:method` - HTTP method (required)
    - `:path` - request path (required)
    - `:body` - request body (default: "")
    - `:secret` - shared secret (required)
    - `:timestamp` - override timestamp (default: current time)
    - `:algorithm` - hash algorithm (default: :sha256)
  """
  def sign_headers(opts) do
    timestamp = Keyword.get(opts, :timestamp, to_string(System.os_time(:second)))
    opts = Keyword.put(opts, :timestamp, timestamp)
    signature = sign(opts)

    [
      {@signature_header, signature},
      {@timestamp_header, to_string(timestamp)}
    ]
  end

  @doc """
  Verify a signature against request parameters.

  Returns `:ok` or `{:error, reason}`.
  """
  def verify_signature(opts) do
    signature = Keyword.fetch!(opts, :signature)
    method = opts |> Keyword.fetch!(:method) |> String.upcase()
    path = Keyword.fetch!(opts, :path)
    body = Keyword.get(opts, :body, "")
    secret = Keyword.fetch!(opts, :secret)
    timestamp = Keyword.fetch!(opts, :timestamp) |> to_string()
    max_age = Keyword.get(opts, :max_age, @default_max_age)
    algorithm = Keyword.get(opts, :algorithm, @algorithm)

    with {:ok, ts} <- parse_timestamp(timestamp),
         :ok <- validate_timestamp(ts, max_age) do
      expected = compute_signature(method, path, timestamp, body, secret, algorithm)

      if Plug.Crypto.secure_compare(expected, signature) do
        :ok
      else
        {:error, :invalid_signature}
      end
    end
  end

  # --- Private ---

  defp compute_signature(method, path, timestamp, body, secret, algorithm) do
    payload = "#{String.upcase(method)}\n#{path}\n#{timestamp}\n#{body}"

    :crypto.mac(:hmac, algorithm, secret, payload)
    |> Base.encode16(case: :lower)
  end

  defp get_header(conn, header) do
    case Plug.Conn.get_req_header(conn, header) do
      [value | _] -> {:ok, value}
      [] -> {:error, :missing_header}
    end
  end

  defp parse_timestamp(timestamp_str) do
    case Integer.parse(timestamp_str) do
      {ts, ""} -> {:ok, ts}
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp validate_timestamp(timestamp, max_age) do
    now = System.os_time(:second)
    diff = abs(now - timestamp)

    if diff <= max_age do
      :ok
    else
      {:error, :expired_timestamp}
    end
  end

  defp read_body_cached(conn) do
    case conn.assigns do
      %{raw_body: body} ->
        {:ok, body}

      _ ->
        case Plug.Conn.read_body(conn) do
          {:ok, body, _conn} -> {:ok, body}
          {:more, _body, _conn} -> {:ok, ""}
          {:error, _reason} -> {:ok, ""}
        end
    end
  rescue
    _ -> {:ok, ""}
  end
end
