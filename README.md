# Hibana 火花

> *A single spark can start a prairie fire.*

A lightweight Elixir web framework built on Plug and Cowboy for APIs and microservices. Direct routing like Sinatra, powerful plugins like Phoenix, full OTP under the hood.

- **10 lines** to a production-grade API
- **30+ plugins** for auth, caching, real-time, monitoring
- **Millions of connections** on the BEAM without changing a line
- **Fault tolerance** -- Supervisors restart failures before users notice

## Quick Start

```elixir
# lib/my_app/router.ex
defmodule MyApp.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser

  get "/hello" do
    json(conn, %{message: "Hello, World!"})
  end
end

# lib/my_app/endpoint.ex
defmodule MyApp.Endpoint do
  use Hibana.Endpoint, otp_app: :my_app
end
```

```bash
mix deps.get && mix run
curl http://localhost:4000/hello
# => {"message":"Hello, World!"}
```

## Features

### Core

| Module | Description |
|--------|-------------|
| `Hibana.Router.DSL` | Sinatra-style routing with `get`, `post`, `put`, `patch`, `delete` |
| `Hibana.CompiledRouter` | O(1) compiled pattern-match dispatch |
| `Hibana.Controller` | Response helpers: `json`, `text`, `html`, `redirect`, `send_file` |
| `Hibana.Endpoint` | Application entry point with Cowboy HTTP server |
| `Hibana.Pipeline` | Middleware pipeline DSL |
| `Hibana.Validator` | Request parameter validation with schemas |
| `Hibana.TestHelpers` | Test utilities for request simulation |

### Real-time

| Module | Description |
|--------|-------------|
| `Hibana.WebSocket` | WebSocket handler with `init`, `handle_in`, `handle_info` callbacks |
| `Hibana.LiveView` | Server-rendered real-time HTML with event handling |
| `Hibana.SSE` | Server-Sent Events with chunked transfer and keep-alive |
| `Hibana.Cluster` | Distributed PubSub, node discovery, and RPC |

### Background Processing

| Module | Description |
|--------|-------------|
| `Hibana.Queue` | Background job queue with retry and delayed execution |
| `Hibana.Job` | Simple async job macro |
| `Hibana.PersistentQueue` | Disk-backed queue with ETS/DETS spillover and backpressure |
| `Hibana.Cron` | Cron-style scheduled tasks |
| `Hibana.CircuitBreaker` | Circuit breaker for external service calls |

### Infrastructure

| Module | Description |
|--------|-------------|
| `Hibana.OTPCache` | GenServer-based in-memory cache with TTL |
| `Hibana.GenServer` | Base GenServer with sensible defaults |
| `Hibana.Plugin` | Plugin behavior and runtime registry |
| `Hibana.FileStreamer` | Zero-copy file streaming with Range request support |
| `Hibana.ChunkedUpload` | Streaming multipart uploads (100GB+) |
| `Hibana.CodeReloader` | Hot code reloading for development |
| `Hibana.EventStore` | Event sourcing support |
| `Hibana.Warmup` | Application warmup routines |

### Plugins

**Security & Auth**
`JWT` | `OAuth` (Google, GitHub, Facebook) | `Auth` | `APIKey` | `TOTP` | `RequestSigning` | `CORS` | `ScopedCORS` | `RateLimiter` | `DistributedRateLimiter`

**Request Processing**
`BodyParser` | `Session` | `RequestId` | `Compression` | `ContentNegotiation` | `APIVersioning` | `I18n`

**Monitoring & Ops**
`Logger` | `ColorLogger` | `Metrics` | `HealthCheck` | `GracefulShutdown` | `TelemetryDashboard` | `LiveDashboard`

**Data & Content**
`Cache` | `OTPCache` | `Static` | `Upload` | `GraphQL` | `Search` | `SEO`

**Development & Admin**
`ErrorHandler` | `DevErrorPage` | `Admin` | `LiveViewChannel`

## Showcases

### REST API with Controller

```elixir
defmodule MyApp.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.BodyParser
  plug Hibana.Plugins.CORS, origins: ["*"]

  get "/users", UserController, :index
  get "/users/:id", UserController, :show
  post "/users", UserController, :create
end

defmodule MyApp.UserController do
  use Hibana.Controller

  def index(conn), do: json(conn, %{users: ["Alice", "Bob"]})

  def show(conn) do
    json(conn, %{user: %{id: conn.params["id"]}})
  end

  def create(conn) do
    json(conn, %{created: conn.body_params}, status: 201)
  end
end
```

### JWT-Protected API

```elixir
defmodule MyApp.Router do
  use Hibana.Router.DSL

  plug Hibana.Plugins.JWT, secret: "your-secret", paths: ["/api"]

  get "/api/profile" do
    json(conn, %{user: conn.assigns[:current_user]})
  end
end
```

### WebSocket Chat

```elixir
defmodule MyApp.ChatSocket do
  use Hibana.WebSocket

  def init(conn, _opts), do: {:ok, conn, %{}}

  def handle_in(message, state) do
    {:reply, {:text, "Echo: #{message}"}, state}
  end
end
```

### Background Jobs with Retry

```elixir
defmodule MyApp.SendEmail do
  use Hibana.Queue.Job

  def perform(data) do
    Mailer.send(data[:to], data[:subject], data[:body])
  end
end

# Enqueue with 3 retries and 5-second delay
SendEmail.enqueue(%{to: "user@example.com"}, delay: 5000, retry: 3)
```

### Cron Scheduler

```elixir
defmodule MyApp.Scheduler do
  use Hibana.Cron

  cron "*/5 * * * *", :cleanup_sessions
  cron "0 0 * * *", :daily_report

  def cleanup_sessions, do: Session.cleanup_expired()
  def daily_report, do: Reports.generate_daily()
end
```

## Comparison

| | Hibana | Phoenix | Plug |
|---|--------|---------|------|
| **Setup** | Minimal | Generator with conventions | Minimal |
| **Routing** | Sinatra-style DSL | MVC-style | Manual |
| **Inline handlers** | Yes | No | No |
| **Plugins** | 30+ built-in | Rich ecosystem | Minimal |
| **LiveView** | Basic pattern | Industry-leading | No |
| **Learning curve** | ~1 hour | ~1 day | ~1 hour |
| **Best for** | APIs, microservices | Full-stack web apps | Libraries, middleware |

Hibana is not a Phoenix replacement. Phoenix is the right choice for full-stack web applications with complex front-ends. Hibana targets developers building APIs, microservices, and lightweight backends who want direct routing with batteries included.

## The Name

> **火花** (Hibana) -- *noun.* A spark. The flash of light when steel strikes stone.

In the Japanese blacksmith tradition, the spark is the beginning of everything. Days of folding and hammering follow, but nothing starts without that initial flash from steel against stone. Hibana follows the same philosophy:

1. **一撃 (Ichigeki)** -- One strike. One route. Start small.
2. **重ねる (Kasaneru)** -- Layer by layer. Add plugins as you grow.
3. **鍛える (Kitaeru)** -- Forge under pressure. The BEAM handles the heat.
4. **折れない (Orenai)** -- Unbreakable. Supervisors catch every fall.

## Sample Apps

| App | Port | Description |
|-----|------|-------------|
| `hello_world` | 4000 | Basic routing |
| `rest_api` | 4001 | REST API with Users and Posts |
| `auth_jwt` | 4002 | JWT authentication |
| `websocket_chat` | 4003 | WebSocket chat |
| `liveview_counter` | 4004 | LiveView counter |
| `background_jobs` | 4005 | Background jobs with Queue |

```bash
cd sample_apps/hello_world && mix deps.get && mix run
```

## Commands

```bash
# Server
mix run                              # Start server
mix server                           # Start server (alias)

# Generators
mix gen.app my_app                   # New project
mix gen.controller User              # Controller
mix gen.model User name:string       # Model
mix gen.scaffold User name:string    # Full scaffold
mix gen.migration create_users       # Migration

# Utilities
mix routes                           # List routes
mix secret                           # Generate secret key

# Database
mix db.create                        # Create database
mix db.migrate                       # Run migrations
mix db.rollback                      # Rollback migration
mix db.seed                          # Seed data

# Tests
cd apps/hibana && MIX_ENV=test mix test
cd apps/hibana_plugins && MIX_ENV=test mix test
```

## Architecture

```
hibana/
├── apps/
│   ├── hibana/                # Core framework
│   ├── hibana_plugins/        # 30+ built-in plugins
│   ├── hibana_ecto/           # Database support (MySQL, PostgreSQL, MongoDB)
│   └── hibana_generator/      # Mix tasks and project generator
├── sample_apps/               # Demo applications
└── config/
```

## License

MIT -- see [LICENSE](LICENSE) for details.
