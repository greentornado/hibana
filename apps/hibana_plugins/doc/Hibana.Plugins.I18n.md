# `Hibana.Plugins.I18n`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/i18n.ex#L1)

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

# `available_locales`

# `before_send`

# `put_translations`

# `start_link`

# `t`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
