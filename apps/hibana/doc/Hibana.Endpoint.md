# `Hibana.Endpoint`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/endpoint.ex#L1)

HTTP endpoint module that starts the Cowboy HTTP server.

## Usage

    defmodule MyApp.Endpoint do
      use Hibana.Endpoint, otp_app: :my_app
    end

## Configuration

Add to your config:

    config :my_app, MyApp.Endpoint,
      http: [ip: {0, 0, 0, 0}, port: 4000],
      secret_key_base: "your-secret-key-base-at-least-64-bytes-long"

## Starting the Endpoint

The endpoint is typically started as part of your application supervision tree:

    defmodule MyApp do
      use Application

      def start(_type, _args) do
        children = [MyApp.Endpoint]
        Supervisor.start_link(children, strategy: :one_for_one)
      end
    end

## Child Spec

The endpoint implements the `child_spec/1` callback for use in supervision trees:

    Supervisor.child_spec({MyApp.Endpoint, []})

# `call`

# `child_spec`

Return a child specification for use in a supervision tree.

# `init`

```elixir
@spec init(any()) :: any()
```

A plug that may be invoked during requests.

# `start_link`

Called when the endpoint is started.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
