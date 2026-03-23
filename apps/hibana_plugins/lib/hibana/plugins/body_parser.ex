defmodule Hibana.Plugins.BodyParser do
  @moduledoc """
  Request body parser for JSON and form data.

  ## Features

  - JSON parsing with configurable decoder
  - URL-encoded form data parsing
  - Automatic content-type detection
  - Parsed data stored in `conn.body_params`

  ## Usage

      # Enable JSON and URL-encoded parsing (default)
      plug Hibana.Plugins.BodyParser

      # Custom configuration
      plug Hibana.Plugins.BodyParser,
        parsers: [:json, :urlencoded],
        json_decoder: Jason

  ## Options

  - `:parsers` - List of enabled parsers (default: `[:json, :urlencoded]`)
  - `:json_decoder` - JSON decoder module (default: `Jason`)

  ## Parsed Data

  After parsing, the request body is available in:

      conn.body_params  # Map of parsed body data

  Example:

      # POST body: {"name": "John", "email": "john@example.com"}
      conn.body_params["name"]  # => "John"
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      parsers: Keyword.get(opts, :parsers, [:json, :urlencoded]),
      json_decoder: Keyword.get(opts, :json_decoder, Jason)
    }
  end

  @impl true
  def call(conn, %{parsers: parsers, json_decoder: decoder}) do
    case get_req_header(conn, "content-type") do
      [content_type | _] ->
        cond do
          :json in parsers && String.starts_with?(content_type, "application/json") ->
            parse_json(conn, decoder)

          :urlencoded in parsers &&
              String.starts_with?(content_type, "application/x-www-form-urlencoded") ->
            parse_urlencoded(conn)

          true ->
            conn
        end

      _ ->
        conn
    end
  end

  defp parse_json(conn, decoder) do
    case read_body(conn) do
      {:ok, body, conn} ->
        case decoder.decode(body) do
          {:ok, parsed} ->
            %{conn | body_params: Map.new(parsed)}

          {:error, _} ->
            conn
        end

      {:more, _partial, conn} ->
        conn
    end
  end

  defp parse_urlencoded(conn) do
    case read_body(conn) do
      {:ok, body, conn} ->
        params = URI.decode_query(body)
        %{conn | body_params: Map.new(params)}

      {:more, _partial, conn} ->
        conn
    end
  end
end
