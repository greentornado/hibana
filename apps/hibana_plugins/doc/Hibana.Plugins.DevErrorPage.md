# `Hibana.Plugins.DevErrorPage`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/dev_error_page.ex#L1)

Rich error pages for development with stack traces, request info, and code context.

## Usage

    # Only in dev!
    plug Hibana.Plugins.DevErrorPage

## Options

- `:enabled` - Whether the dev error page rendering is active (default: `true`)

# `before_send`

# `render_exception`

Render an exception as a rich HTML error page

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
