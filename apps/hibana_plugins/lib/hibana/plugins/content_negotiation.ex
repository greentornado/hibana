defmodule Hibana.Plugins.ContentNegotiation do
  @moduledoc """
  Content Negotiation plugin for format selection (JSON/XML/CSV/etc).

  ## Features

  - Automatic format selection based on Accept header
  - Supports JSON, XML, HTML, Text, CSV formats
  - Custom format renderer via `render_as/3`
  - Falls back to default format if none matches

  ## Usage

      # Enable with JSON only (default)
      plug Hibana.Plugins.ContentNegotiation

      # Multiple formats
      plug Hibana.Plugins.ContentNegotiation,
        formats: ["json", "xml", "html"],
        default: "json"

  ## Options

  - `:formats` - Supported formats (default: `["json"]`)
  - `:default` - Default format (default: `"json"`)

  ## Supported Formats

  | Format | Content-Type |
  |--------|--------------|
  | json   | application/json |
  | xml    | application/xml |
  | html   | text/html |
  | text   | text/plain |
  | csv    | text/csv |

  ## Conn Assignments

  After negotiation:

      conn.assigns.response_format       # => "json"
      conn.assigns.response_content_type   # => "application/json"

  ## Rendering Responses

  Use `render_as/3` to render in the negotiated format:

      defmodule MyController do
        use Hibana.Controller

        def index(conn) do
          data = %{users: [...]}
          format = conn.assigns.response_format || "json"
          render_as(conn, format, data)
        end
      end
  """

  use Hibana.Plugin
  import Plug.Conn

  @formats %{
    "json" => "application/json",
    "xml" => "application/xml",
    "html" => "text/html",
    "text" => "text/plain",
    "csv" => "text/csv"
  }

  @impl true
  def init(opts) do
    %{
      formats: Keyword.get(opts, :formats, ["json"]),
      default: Keyword.get(opts, :default, "json")
    }
  end

  @impl true
  def call(conn, %{formats: formats, default: default}) do
    format = negotiate_format(conn, formats, default)
    content_type = Map.get(@formats, format, "application/json")

    conn
    |> assign(:response_format, format)
    |> assign(:response_content_type, content_type)
  end

  defp negotiate_format(conn, formats, default) do
    accept = get_req_header(conn, "accept") |> List.first()

    preferred =
      case accept do
        nil ->
          default

        h ->
          format = find_format_from_accept(h, formats)
          format || default
      end

    case get_req_header(conn, "content-type") do
      [ct | _] ->
        if format_from_content_type(ct, formats),
          do: format_from_content_type(ct, formats),
          else: preferred

      _ ->
        preferred
    end
  end

  defp find_format_from_accept(accept, formats) do
    Enum.find(formats, fn f ->
      String.contains?(accept, Map.get(@formats, f, f))
    end)
  end

  defp format_from_content_type(ct, formats) do
    Enum.find(formats, fn f ->
      String.contains?(ct, Map.get(@formats, f, f))
    end)
  end

  def render_as(conn, format, data) do
    content_type = Map.get(@formats, format, "application/json")

    result =
      case format do
        "json" -> Jason.encode!(data)
        "xml" -> convert_to_xml(data)
        "csv" -> convert_to_csv(data)
        _ -> Jason.encode!(data)
      end

    conn
    |> put_resp_content_type(content_type)
    |> send_resp(200, result)
  end

  defp convert_to_xml(data) when is_map(data) do
    items =
      Enum.map_join(data, fn {k, v} ->
        "<#{xml_safe_key(k)}>#{xml_value(v)}</#{xml_safe_key(k)}>"
      end)

    "<?xml version=\"1.0\"?><root>#{items}</root>"
  end

  defp xml_safe_key(key) do
    key
    |> to_string()
    |> String.replace(~r/[^a-zA-Z0-9_\-.]/, "_")
    |> then(fn
      <<c, _::binary>> = s when c in ?a..?z or c in ?A..?Z or c == ?_ -> s
      s -> "_" <> s
    end)
  end

  defp xml_value(v) when is_map(v),
    do:
      Enum.map_join(v, fn {k, val} ->
        "<#{xml_safe_key(k)}>#{xml_value(val)}</#{xml_safe_key(k)}>"
      end)

  defp xml_value(v) when is_list(v),
    do: Enum.map_join(v, fn item -> "<item>#{xml_value(item)}</item>" end)

  defp xml_value(v),
    do:
      to_string(v)
      |> String.replace("&", "&amp;")
      |> String.replace("<", "&lt;")
      |> String.replace(">", "&gt;")

  defp convert_to_csv(data) when is_list(data) do
    if Enum.empty?(data) do
      ""
    else
      case hd(data) do
        row when is_map(row) ->
          headers = Map.keys(row) |> Enum.map(&to_string/1)
          header_line = Enum.join(headers, ",")

          rows =
            Enum.map_join(data, "\n", fn row ->
              Enum.map_join(headers, ",", fn h ->
                value = row |> Map.get(h, "") |> to_string()
                csv_escape(value)
              end)
            end)

          header_line <> "\n" <> rows

        _ ->
          Enum.map_join(data, "\n", &to_string/1)
      end
    end
  end

  defp convert_to_csv(_), do: ""

  defp csv_escape(value) do
    if String.contains?(value, [",", "\"", "\n"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end
end
