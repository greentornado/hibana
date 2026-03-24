# `Hibana.CodeReloader`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/code_reloader.ex#L1)

Hot code reloading for development. Watches source files and automatically
recompiles when changes are detected.

## Usage

    # Add to your supervision tree (dev only)
    if Mix.env() == :dev do
      children = [
        {Hibana.CodeReloader, dirs: ["lib"], interval: 1_000}
      ]
    end

## Options
- `:dirs` - Directories to watch (default: `["lib"]`)
- `:interval` - Poll interval in ms (default: `1_000`)
- `:callback` - Function called after recompile (default: `nil`)

# `child_spec`

Returns a specification to start this module under a supervisor.

See `Supervisor`.

# `init`

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
