# `Hibana.Plugin`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugin.ex#L1)

Behaviour for Hibana plugins.

## Example

    defmodule MyApp.AuthPlugin do
      @behaviour Hibana.Plugin

      def init(opts) do
        # Initialize plugin with options
        opts
      end

      def call(conn, _opts) do
        # Process the request
        conn
      end

      def before_send(conn, _opts) do
        # Called before response is sent
        conn
      end
    end

# `before_send`
*optional* 

```elixir
@callback before_send(conn :: Plug.Conn.t(), opts :: any()) :: Plug.Conn.t()
```

Called just before the response is sent. Use this for cleanup or
adding response headers.

# `call`

```elixir
@callback call(conn :: Plug.Conn.t(), opts :: any()) :: Plug.Conn.t()
```

Called for each request. This is the main entry point for the plugin.
Must return the connection, possibly with modifications.

# `init`

```elixir
@callback init(opts :: any()) :: any()
```

Called when the plugin is initialized. Use this to set up state and
validate options.

# `start_link`
*optional* 

```elixir
@callback start_link(opts :: any()) :: {:ok, pid()} | {:error, term()}
```

Optional. Called when the plugin is started.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
