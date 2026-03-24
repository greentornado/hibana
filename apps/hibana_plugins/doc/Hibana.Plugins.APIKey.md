# `Hibana.Plugins.APIKey`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/api_key.ex#L1)

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

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
