# `Hibana.Plugins.ColorLogger`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/color_logger.ex#L1)

Pretty-printed colored request logger with timing breakdown.

## Usage

    plug Hibana.Plugins.ColorLogger

## Output Example

    | GET /api/users
    | Status: 200 OK
    | Duration: 12.4ms
    | Params: %{"page" => "1"}
    +-----------------------

## Options

- `:level` - Logger level to use for output (default: `:info`)
- `:include_params` - Whether to log request parameters (default: `true`)
- `:include_headers` - Whether to log request headers (default: `false`)

# `before_send`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
