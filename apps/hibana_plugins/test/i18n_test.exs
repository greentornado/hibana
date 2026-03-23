defmodule Hibana.Plugins.I18nTest do
  use ExUnit.Case, async: false

  alias Hibana.Plugins.I18n

  setup do
    # Clean up ETS table between tests
    case :ets.whereis(:hibana_i18n) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(:hibana_i18n)
    end

    :ok
  end

  describe "put_translations/2 and t/3" do
    test "stores and retrieves translations" do
      I18n.put_translations("en", %{"hello" => "Hello!"})
      assert I18n.t("en", "hello") == "Hello!"
    end

    test "interpolation with bindings" do
      I18n.put_translations("en", %{"greeting" => "Hello, %{name}! You have %{count} messages."})
      result = I18n.t("en", "greeting", name: "Alice", count: 5)
      assert result == "Hello, Alice! You have 5 messages."
    end

    test "falls back to en when locale not found" do
      I18n.put_translations("en", %{"fallback" => "English fallback"})
      assert I18n.t("fr", "fallback") == "English fallback"
    end

    test "returns key when no translation found" do
      assert I18n.t("zz", "nonexistent_key") == "nonexistent_key"
    end
  end

  describe "call/2 locale detection" do
    test "detects locale from accept-language header" do
      opts = I18n.init(locales: ["en", "vi", "ja"])

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("accept-language", "vi-VN,vi;q=0.9,en;q=0.8")
        |> Plug.Conn.fetch_query_params()
        |> I18n.call(opts)

      assert conn.assigns[:locale] == "vi"
    end

    test "detects locale from query param" do
      opts = I18n.init(locales: ["en", "ja"], detect_from: [:query])

      conn =
        Plug.Test.conn(:get, "/?locale=ja")
        |> Plug.Conn.fetch_query_params()
        |> I18n.call(opts)

      assert conn.assigns[:locale] == "ja"
    end

    test "falls back to default locale" do
      opts = I18n.init(default_locale: "en", locales: ["en"])

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.fetch_query_params()
        |> I18n.call(opts)

      assert conn.assigns[:locale] == "en"
    end
  end
end
