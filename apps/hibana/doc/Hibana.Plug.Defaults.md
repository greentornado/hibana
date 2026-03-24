# `Hibana.Plug.Defaults`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plug/defaults.ex#L1)

Default plug for request processing.

## Features

- Fetches query parameters
- Assigns params to conn

## Usage

Included automatically in Endpoint:

    use Plug.Builder, plug: Hibana.Plug.Defaults

## What It Does

1. Calls `fetch_query_params/1` to parse query string
2. Assigns `params` to conn for easy access

# `call`

# `init`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
