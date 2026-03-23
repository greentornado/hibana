defmodule Hibana.Plugins.I18n do
  @moduledoc """
  Built-in internationalization with locale detection from Accept-Language header,
  translation storage, and interpolation.

  ## Usage

      plug Hibana.Plugins.I18n, default_locale: "en", locales: ["en", "vi", "ja"]

      # Register translations
      Hibana.Plugins.I18n.put_translations("en", %{
        "hello" => "Hello, %{name}!",
        "welcome" => "Welcome to our app"
      })

      Hibana.Plugins.I18n.put_translations("vi", %{
        "hello" => "Xin chao, %{name}!",
        "welcome" => "Chao mung ban den voi ung dung"
      })

      # In controller
      def index(conn) do
        locale = conn.assigns[:locale]
        greeting = Hibana.Plugins.I18n.t(locale, "hello", name: "Alice")
        json(conn, %{message: greeting})
      end

  ## Options

  - `:default_locale` - Fallback locale when detection fails (default: `"en"`)
  - `:locales` - List of supported locale strings (default: `["en"]`)
  - `:detect_from` - Ordered list of sources to detect locale from; valid values are `:header`, `:query`, and `:cookie` (default: `[:header, :query, :cookie]`)
  """

  use Hibana.Plugin
  import Plug.Conn

  @table :hibana_i18n

  @impl true
  def init(opts) do
    ensure_table()

    %{
      default_locale: Keyword.get(opts, :default_locale, "en"),
      locales: Keyword.get(opts, :locales, ["en"]),
      detect_from: Keyword.get(opts, :detect_from, [:header, :query, :cookie])
    }
  end

  @impl true
  def call(conn, %{default_locale: default, locales: locales, detect_from: sources}) do
    conn = Plug.Conn.fetch_query_params(conn)
    locale = detect_locale(conn, sources, locales) || default
    assign(conn, :locale, locale)
  end

  def t(locale, key, bindings \\ []) do
    ensure_table()

    case :ets.lookup(@table, {locale, key}) do
      [{_, value}] ->
        interpolate(value, bindings)

      _ ->
        case :ets.lookup(@table, {"en", key}) do
          [{_, value}] -> interpolate(value, bindings)
          _ -> key
        end
    end
  end

  def put_translations(locale, translations) when is_map(translations) do
    ensure_table()

    Enum.each(translations, fn {key, value} ->
      :ets.insert(@table, {{locale, key}, value})
    end)
  end

  def available_locales do
    ensure_table()

    :ets.foldl(fn {{locale, _}, _}, acc -> MapSet.put(acc, locale) end, MapSet.new(), @table)
    |> MapSet.to_list()
  end

  defp detect_locale(conn, sources, locales) do
    Enum.find_value(sources, fn
      :header ->
        parse_accept_language(conn, locales)

      :query ->
        conn.query_params["locale"]

      :cookie ->
        case get_req_header(conn, "cookie") do
          [cookies | _] ->
            cookies
            |> String.split("; ")
            |> Enum.find_value(fn c ->
              case String.split(c, "=", parts: 2) do
                ["locale", v] -> if v in locales, do: v
                _ -> nil
              end
            end)

          _ ->
            nil
        end
    end)
  end

  defp parse_accept_language(conn, locales) do
    case get_req_header(conn, "accept-language") do
      [header | _] ->
        header
        |> String.split(",")
        |> Enum.map(fn part ->
          case String.split(String.trim(part), ";") do
            [lang | _] -> String.trim(lang) |> String.split("-") |> hd()
          end
        end)
        |> Enum.find(fn lang -> lang in locales end)

      _ ->
        nil
    end
  end

  defp interpolate(str, []), do: str

  defp interpolate(str, bindings) do
    Enum.reduce(bindings, str, fn {key, val}, acc ->
      String.replace(acc, "%{#{key}}", to_string(val))
    end)
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :set, :public, read_concurrency: true])
        rescue
          ArgumentError -> :ok
        end
      _ -> :ok
    end
  end
end
