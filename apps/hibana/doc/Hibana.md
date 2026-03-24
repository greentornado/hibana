# `Hibana`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana.ex#L1)

Hibana - A lightweight web framework for Elixir.

## Overview

Hibana is a lightweight web framework inspired by Plug and Phoenix,
designed for simplicity and OTP integration.

## Core Components

### Router
Define routes using a DSL:

    defmodule MyApp.Router do
      use Hibana.Router.DSL

      plug(Hibana.Plugins.BodyParser)
      plug(Hibana.Plugins.Logger)

      get "/hello", fn conn ->
        json(conn, %{message: "Hello, World!"})
      end

      get "/users", UserController, :index
      post "/users", UserController, :create
    end

### Controller
Handle requests with response helpers:

    defmodule MyApp.UserController do
      use Hibana.Controller

      def index(conn) do
        json(conn, %{users: []})
      end
    end

### Endpoint
Start the HTTP server:

    defmodule MyApp.Endpoint do
      use Hibana.Endpoint, otp_app: :my_app
    end

### Plugins
Extend functionality with plugins:

    plug(Hibana.Plugins.JWT, secret: "secret")
    plug(Hibana.Plugins.CORS)
    plug(Hibana.Plugins.RateLimiter)

## Quick Start

    # mix.exs
    def application do
      [mod: {MyApp, []}]
    end

    # lib/my_app.ex
    defmodule MyApp do
      use Application
      def start(_type, _args) do
        children = [MyApp.Endpoint]
        Supervisor.start_link(children, strategy: :one_for_one)
      end
    end

## Available Plugins

- `Hibana.Plugins.BodyParser` - Parse JSON/form bodies
- `Hibana.Plugins.Session` - Cookie sessions
- `Hibana.Plugins.JWT` - JWT authentication
- `Hibana.Plugins.Auth` - Basic auth
- `Hibana.Plugins.CORS` - Cross-origin support
- `Hibana.Plugins.RateLimiter` - Rate limiting
- `Hibana.Plugins.Cache` - ETS caching
- `Hibana.Plugins.Logger` - Request logging
- `Hibana.Plugins.HealthCheck` - Health endpoints
- `Hibana.Plugins.Metrics` - Prometheus metrics
- And more...

# `version`

Returns the application version.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
