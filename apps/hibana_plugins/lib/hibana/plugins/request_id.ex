defmodule Hibana.Plugins.RequestId do
  @moduledoc """
  Request ID and tracing plugin for debugging and log correlation.

  ## Features

  - Generates unique request IDs for each request
  - Uses existing X-Request-ID header if provided
  - Adds request ID to response headers
  - Available in conn.assigns for application use

  ## Usage

      # Basic usage
      plug Hibana.Plugins.RequestId

      # With custom header name
      plug Hibana.Plugins.RequestId, header: "x-correlation-id"

  ## Options

  - `:header` - Request/response header name (default: `"x-request-id"`)
  - `:generate_if_missing` - Generate ID if not provided (default: `true`)

  ## Conn Assignments

      conn.assigns.request_id  # => "a1b2c3d4e5f6g7h8"

  ## Response Header

  Returns the request ID in the configured header:

      X-Request-ID: a1b2c3d4e5f6g7h8

  ## ID Format

  16 bytes random data, hex-encoded (32 characters).
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      header: Keyword.get(opts, :header, "x-request-id"),
      generate_if_missing: Keyword.get(opts, :generate_if_missing, true)
    }
  end

  @impl true
  def call(conn, %{header: header, generate_if_missing: generate}) do
    request_id = get_or_generate_request_id(conn, header, generate)

    conn = assign(conn, :request_id, request_id)

    if request_id do
      put_resp_header(conn, header, request_id)
    else
      conn
    end
  end

  defp get_or_generate_request_id(conn, header, generate) do
    case get_req_header(conn, header) do
      [id | _] when id != "" -> id
      _ when generate -> generate_request_id()
      _ -> nil
    end
  end

  defp generate_request_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end
end
