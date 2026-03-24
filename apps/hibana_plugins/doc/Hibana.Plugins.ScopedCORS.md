# `Hibana.Plugins.ScopedCORS`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/scoped_cors.ex#L1)

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

# `apply`

Apply CORS headers to a connection with given options

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
