# Hibana Framework - Project Plan

## Project Overview

Build a lightweight Elixir web framework based on Plug with:
- **Direct routing** like Sinatra/FastAPI (no complex pipeline)
- **Powerful plugins** like Phoenix
- **Full OTP power** - umbrella, Genservers, Supervisors
- **Project template** for generating new projects

## Unique Performance Features

1. **Pre-compiled routing** — Routes compile to BEAM pattern-match functions at build time for O(1) dispatch. No list iteration. No string comparison loops. The Erlang VM's native pattern matching engine handles dispatch.

2. **Super fast routing** — `use Hibana.CompiledRouter` generates function clauses like `def match("GET", ["users", id])` at compile time, giving constant-time dispatch regardless of route count.

3. **Super fast WebSocket** — Direct Cowboy WebSocket integration with `@behaviour` callbacks. No middleware layers between your handler and the socket. Microsecond-level latency.

4. **Cluster support built-in** — `Hibana.Cluster` provides distributed PubSub, node discovery (EPMD/DNS/gossip), RPC helpers, and automatic reconnection. No external dependencies like `libcluster` needed.

5. **File streaming / zero-copy** — `Hibana.FileStreamer` uses the `sendfile(2)` syscall via Cowboy to transfer files directly from disk to socket without copying through userspace. Supports HTTP Range requests for video seeking and resumable downloads.

6. **SSE (Server-Sent Events)** — `Hibana.SSE` provides built-in SSE endpoint support with chunked transfer encoding, automatic keep-alive, mailbox-based streaming, and W3C-compliant event formatting.

7. **Large file upload (100GB+)** — `Hibana.ChunkedUpload` streams the request body directly to disk without loading into memory. Supports chunked/resumable uploads with progress tracking and automatic stale upload cleanup.

8. **Large queue support** — `Hibana.PersistentQueue` handles millions of jobs with ETS for hot jobs and DETS for disk spillover. Features priority ordering, exponential backoff retries, concurrency control, backpressure, and graceful shutdown with job persistence.

9. **Latest dependency versions** — All mix dependencies kept at latest compatible versions.

## Core Design Decisions

### 1. Routing System
```elixir
# Sinatra-style direct routing
get "/users", UserController, :index
post "/users", UserController, :create

# Inline handlers
get "/hello", fn conn -> Plug.Conn.send_resp(conn, 200, "Hello!") end
```

### 2. Plugin System
- Pluggable architecture like Phoenix endpoint
- `use MyApp.Plugin` macro to add custom behavior
- Support: authentication, caching, logging, rate limiting

### 3. OTP Integration
- Built-in Supervisor tree
- Genserver for stateful components
- Registry + DynamicSupervisor for runtime plugins

## Project Structure (Umbrella)

```
hibana/
├── apps/
│   ├── hibana/       # Core framework (Plug + Router)
│   │   ├── lib/
│   │   │   ├── hibana/
│   │   │   │   ├── core/
│   │   │   │   │   ├── router.ex
│   │   │   │   │   ├── controller.ex
│   │   │   │   │   ├── endpoint.ex
│   │   │   │   │   ├── web_socket.ex
│   │   │   │   │   ├── live_view.ex
│   │   │   │   │   ├── queue.ex
│   │   │   │   │   ├── job.ex
│   │   │   │   │   ├── otp_cache.ex
│   │   │   │   │   ├── compiled_router.ex
│   │   │   │   │   ├── sse.ex
│   │   │   │   │   ├── cluster.ex
│   │   │   │   │   ├── file_streamer.ex
│   │   │   │   │   ├── chunked_upload.ex
│   │   │   │   │   ├── persistent_queue.ex
│   │   │   │   │   ├── code_reloader.ex
│   │   │   │   │   ├── validator.ex
│   │   │   │   │   ├── circuit_breaker.ex
│   │   │   │   │   ├── cron.ex
│   │   │   │   │   ├── pipeline.ex
│   │   │   │   │   ├── test_helpers.ex
│   │   │   │   │   ├── event_store.ex
│   │   │   │   │   ├── features.ex
│   │   │   │   │   ├── warmup.ex
│   │   │   │   │   └── plugin/
│   │   │   │   └── plugin.ex
│   │   └── test/
│   ├── hibana_plugins/     # Built-in plugins (35 plugins)
│   │   └── lib/
│   ├── hibana_ecto/        # Ecto database support (MySQL, PostgreSQL, MongoDB)
│   │   └── lib/
│   └── hibana_generator/  # CLI tools & project generator
│       └── lib/mix/tasks/
├── config/
├── mix.exs
└── README.md
```

## Implemented Features

### Core Framework
- **Router** - Pattern matching based routing, macro-based DSL (get, post, put, delete, patch)
- **Controller** - Base controller with action helpers (json, text, html, redirect, send_file)
- **Endpoint** - Application entry point with Cowboy HTTP server
- **WebSocket** - WebSocket handler behavior with callbacks
- **LiveView** - Server-rendered real-time HTML pattern
- **Queue** - Background job queue with retry and delayed execution
- **Job** - Simple async job macro
- **GenServer** - Base GenServer with defaults
- **OTPCache** - GenServer-based in-memory cache with TTL
- **Plugin** - Plugin behavior and registry
- **CompiledRouter** - Compile-time route compilation to BEAM pattern matching for O(1) dispatch
- **SSE** - Server-Sent Events support with chunked streaming and keep-alive
- **Cluster** - Built-in cluster support with distributed PubSub and node discovery
- **FileStreamer** - Zero-copy file streaming using sendfile(2) with Range request support
- **ChunkedUpload** - Large file uploads (100GB+) with streaming, chunked/resumable support
- **PersistentQueue** - High-performance persistent queue with disk spillover and backpressure
- **CodeReloader** - Hot code reloading for development (file watching + auto-recompile)
- **Validator** - Schema-based request parameter validation with type casting
- **CircuitBreaker** - Circuit breaker for external service calls
- **Cron** - Built-in cron scheduler with cron expressions
- **Pipeline** - Middleware pipeline DSL with route groups
- **TestHelpers** - Test helpers for controller/route testing
- **EventStore** - Event sourcing with projections and subscriptions
- **Features** - Feature toggle system for enabling/disabling components via config
- **Warmup** - Pre-load data and compile templates on startup

### Built-in Plugins (35 plugins)

| Plugin | Description |
|--------|-------------|
| CORS | Cross-Origin Resource Sharing |
| RateLimiter | Token bucket rate limiting |
| Auth | Basic authentication |
| JWT | JWT token authentication (HS256/384/512) |
| OAuth | OAuth 2.0 (Google, GitHub, Facebook) |
| Static | Static file serving |
| BodyParser | JSON/Form parsing |
| Session | Cookie-based sessions |
| Logger | Request/Response logging |
| ErrorHandler | Custom 404/500 handling |
| GraphQL | GraphQL endpoint with Playground |
| Cache | ETS-based caching with TTL |
| OTPCache | GenServer-based cache |
| HealthCheck | Health endpoint for K8s/load balancer |
| Metrics | Telemetry with Prometheus format |
| APIVersioning | Versioned APIs (path/header/query) |
| RequestId | Request tracing/correlation |
| ContentNegotiation | Format negotiation (JSON/XML/CSV) |
| Upload | File upload endpoint |
| GracefulShutdown | Graceful shutdown for deployment |
| LiveViewChannel | WebSocket channel for LiveView |
| DevErrorPage | Rich error pages with stack traces (dev only) |
| ColorLogger | Pretty-printed colored request logger with timing |
| APIKey | API key authentication (header/query/bearer) |
| Compression | gzip/deflate response compression |
| TelemetryDashboard | Web-based dashboard showing live metrics |
| DistributedRateLimiter | Rate limiting across cluster nodes |
| ScopedCORS | Per-route CORS configuration |
| Admin | Auto-generated CRUD admin dashboard with Ant Design theme |
| I18n | Internationalization with locale detection and translations |
| LiveDashboard | Live system dashboard (processes, ETS, memory, ports) |
| RequestSigning | HMAC request signing for API-to-API auth |
| Search | Meilisearch full-text search integration |
| SEO | Meta tags, JSON-LD, OpenGraph, sitemap.xml, robots.txt |
| TOTP | Two-factor authentication with TOTP/Google Authenticator |

## Implementation Phases

### Phase 1: Core Framework ✅
1. **Router** - Pattern matching based routing, macro-based DSL
2. **Controller** - Base controller with action helpers
3. **Plug Integration** - Pipeline builder, before/after hooks
4. **Endpoint** - Application entry point with Supervisor

### Phase 2: Plugin System ✅
1. **Plugin Behavior** - Define `Hibana.Plugin` behavior
2. **Plugin Registry** - Genserver for runtime plugin management
3. **Built-in Plugins** - Auth, CORS, Rate Limit, Cache, etc.

### Phase 3: Real-time Features ✅
1. **WebSocket** - Full WebSocket handler with callbacks
2. **LiveView** - Server-rendered real-time HTML pattern
3. **LiveViewChannel** - WebSocket channel for LiveView

### Phase 4: Background Jobs ✅
1. **Queue** - Persistent queue with retry and scheduling
2. **Job** - Simple async job macro

### Phase 5: Advanced Features ✅
1. **Metrics/Telemetry** - Request duration and count tracking
2. **Health Check** - Built-in health endpoint
3. **API Versioning** - Path, header, and query-based versioning
4. **Content Negotiation** - JSON/XML/CSV format switching
5. **Graceful Shutdown** - Deployment support

### Phase 6: Performance & Scalability ✅
1. **CompiledRouter** - Compile-time route compilation to BEAM pattern matching
2. **SSE** - Server-Sent Events with chunked streaming
3. **Cluster** - Distributed PubSub and node discovery
4. **FileStreamer** - Zero-copy file streaming with Range support
5. **ChunkedUpload** - Large file uploads with resumable support
6. **PersistentQueue** - Disk-backed queue with backpressure

### Phase 7: Developer Experience & Production ✅
1. **CodeReloader** - Hot code reloading for development with file watching
2. **Validator** - Schema-based request parameter validation with type casting
3. **CircuitBreaker** - Circuit breaker pattern for external service calls
4. **Cron** - Built-in cron scheduler with cron expression support
5. **Pipeline** - Middleware pipeline DSL with route groups
6. **TestHelpers** - Test helpers for controller and route testing
7. **DevErrorPage** - Rich error pages with stack traces for development
8. **ColorLogger** - Pretty-printed colored request logger with timing
9. **APIKey** - API key authentication (header/query/bearer)
10. **Compression** - gzip/deflate response compression
11. **TelemetryDashboard** - Web-based dashboard showing live metrics
12. **DistributedRateLimiter** - Rate limiting across cluster nodes
13. **ScopedCORS** - Per-route CORS configuration
14. **gen.scaffold** - Mix task to generate model + controller + routes for a resource

### Phase 8: Infrastructure & Security ✅
1. **EventStore** - Event sourcing with projections
2. **Features** - Feature toggle system
3. **Warmup** - Startup warmup hooks
4. **I18n** - Internationalization
5. **TOTP/2FA** - Two-factor authentication
6. **RequestSigning** - HMAC request signing
7. **SEO** - Meta tags, JSON-LD, sitemap
8. **Search** - Meilisearch integration
9. **Admin** - CRUD admin dashboard
10. **LiveDashboard** - System monitoring dashboard
11. **Faker** - Test data generation
12. **db.seed** - Database seeding
13. **bench** - Performance benchmarking

## New Features (Phase 6)

### CompiledRouter - O(1) Route Dispatch
Compiles routes at build time into BEAM pattern matching clauses for constant-time dispatch.
```elixir
defmodule MyApp.Router do
  use Hibana.CompiledRouter

  get "/users", UserController, :index
  get "/users/:id", UserController, :show
  post "/users", UserController, :create
end
```

### SSE - Server-Sent Events
Stream real-time events to clients over HTTP with chunked transfer encoding and automatic keep-alive.
```elixir
get "/events", fn conn ->
  Hibana.SSE.stream(conn, fn send_event ->
    send_event.("message", %{text: "Hello!"})
    send_event.("update", %{count: 42})
  end)
end
```

### Cluster - Distributed PubSub
Built-in cluster support with automatic node discovery and distributed PubSub messaging.
```elixir
# Start cluster with node discovery
Hibana.Cluster.start_link(strategy: :gossip)

# Subscribe and publish across nodes
Hibana.Cluster.subscribe("chat:lobby")
Hibana.Cluster.publish("chat:lobby", %{user: "alice", msg: "hi"})
```

### FileStreamer - Zero-Copy File Streaming
Efficient file serving using sendfile(2) system call with support for Range requests (partial content).
```elixir
get "/download/:file", fn conn ->
  Hibana.FileStreamer.send_file(conn, "/path/to/files/" <> conn.params["file"])
end
```

### ChunkedUpload - Large File Uploads
Handle uploads of 100GB+ files with streaming, chunked transfer, and resumable upload support.
```elixir
post "/upload", fn conn ->
  Hibana.ChunkedUpload.receive(conn,
    dest: "/uploads",
    max_size: :infinity,
    chunk_size: 8_388_608,
    on_chunk: fn chunk_info -> IO.inspect(chunk_info) end
  )
end
```

### PersistentQueue - Disk-Backed Queue
High-performance queue that spills to disk when memory limits are reached, with built-in backpressure.
```elixir
{:ok, queue} = Hibana.PersistentQueue.start_link(
  name: :work_queue,
  max_memory_items: 10_000,
  disk_path: "/tmp/queue_data"
)

Hibana.PersistentQueue.enqueue(:work_queue, %{task: "process", id: 1})
{:ok, item} = Hibana.PersistentQueue.dequeue(:work_queue)
```

## New Features (Phase 7)

### CodeReloader - Hot Code Reloading
Watches source files and automatically recompiles on changes during development.
```elixir
# Add to your supervision tree in dev
{Hibana.CodeReloader, dirs: ["lib"], debounce: 500}
```

### Validator - Request Parameter Validation
Schema-based validation with type casting for request parameters.
```elixir
schema = %{
  name: [type: :string, required: true],
  age: [type: :integer, min: 0],
  email: [type: :string, format: ~r/@/]
}

case Hibana.Validator.validate(conn.params, schema) do
  {:ok, validated} -> json(conn, validated)
  {:error, errors} -> json(conn, %{errors: errors}, status: 422)
end
```

### CircuitBreaker - External Service Protection
Circuit breaker pattern to prevent cascading failures from external service calls.
```elixir
{:ok, _} = Hibana.CircuitBreaker.start_link(
  name: :payment_api,
  threshold: 5,
  timeout: 30_000
)

case Hibana.CircuitBreaker.call(:payment_api, fn -> HTTPClient.post(url, body) end) do
  {:ok, response} -> handle_response(response)
  {:error, :circuit_open} -> json(conn, %{error: "Service unavailable"}, status: 503)
end
```

### Cron - Built-in Scheduler
Schedule recurring tasks using cron expressions.
```elixir
defmodule MyApp.Scheduler do
  use Hibana.Cron

  cron "*/5 * * * *", :cleanup_sessions
  cron "0 0 * * *", :daily_report

  def cleanup_sessions, do: Session.cleanup_expired()
  def daily_report, do: Reports.generate_daily()
end
```

### Pipeline - Middleware DSL
Group routes with shared middleware using a pipeline DSL.
```elixir
defmodule MyApp.Router do
  use Hibana.Pipeline

  pipeline :api do
    plug Hibana.Plugins.BodyParser
    plug Hibana.Plugins.RequestId
  end

  pipeline :auth do
    plug Hibana.Plugins.JWT, secret: "secret"
  end

  scope "/api", pipe_through: [:api, :auth] do
    get "/users", UserController, :index
  end
end
```

### TestHelpers - Testing Utilities
Helpers for testing controllers, routes, and plugs.
```elixir
defmodule MyApp.UserControllerTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  test "GET /users returns list" do
    conn = get("/users")
    assert conn.status == 200
    assert json_response(conn)["users"]
  end
end
```

## Key Files

| File | Purpose |
|------|---------|
| `lib/hibana/core/router.ex` | DSL for routes |
| `lib/hibana/core/controller.ex` | Controller base |
| `lib/hibana/core/endpoint.ex` | HTTP server |
| `lib/hibana/core/web_socket.ex` | WebSocket behavior |
| `lib/hibana/core/live_view.ex` | LiveView pattern |
| `lib/hibana/core/queue.ex` | Background job queue |
| `lib/hibana/core/otp_cache.ex` | GenServer cache |
| `lib/hibana/core/plugin.ex` | Plugin behavior |
| `lib/hibana/core/gen_server.ex` | Base Genserver |
| `lib/hibana/core/compiled_router.ex` | Compiled route dispatch |
| `lib/hibana/core/sse.ex` | Server-Sent Events |
| `lib/hibana/core/cluster.ex` | Cluster & distributed PubSub |
| `lib/hibana/core/file_streamer.ex` | Zero-copy file streaming |
| `lib/hibana/core/chunked_upload.ex` | Chunked/resumable uploads |
| `lib/hibana/core/persistent_queue.ex` | Persistent queue with disk spillover |
| `lib/hibana/core/code_reloader.ex` | Hot code reloading for dev |
| `lib/hibana/core/validator.ex` | Request parameter validation |
| `lib/hibana/core/circuit_breaker.ex` | Circuit breaker for external services |
| `lib/hibana/core/cron.ex` | Cron scheduler |
| `lib/hibana/core/pipeline.ex` | Middleware pipeline DSL |
| `lib/hibana/core/test_helpers.ex` | Test utilities |
| `lib/hibana/core/event_store.ex` | Event sourcing |
| `lib/hibana/core/features.ex` | Feature toggles |
| `lib/hibana/core/warmup.ex` | Startup warmup hooks |

## Commands

```bash
# Run the server
mix run
mix server

# Run tests (individual apps)
cd apps/hibana && MIX_ENV=test mix test
cd apps/hibana_plugins && MIX_ENV=test mix test

# Run all tests
cd apps/hibana && MIX_ENV=test mix test
cd apps/hibana_plugins && MIX_ENV=test mix test

# Generate new project
mix gen.app my_app

# CLI Tools
mix gen.controller User
mix gen.model User name:string email:string
mix gen.migration create_users
mix gen.scaffold User name:string email:string
mix routes
mix secret

# Database
mix db.create
mix db.migrate
mix db.rollback
mix db.seed

# Benchmarking
mix bench
```

## Testing

### Test Environment Setup
- Tests run with `MIX_ENV=test` to avoid starting the HTTP server
- Set `start_server: false` in test config to prevent port conflicts
- ExCoveralls is configured for coverage reporting

### Running Tests
```bash
# Test hibana
cd apps/hibana && MIX_ENV=test mix test

# Test hibana_plugins
cd apps/hibana_plugins && MIX_ENV=test mix test

# With coverage
cd apps/hibana && MIX_ENV=test mix test --cover
cd apps/hibana_plugins && MIX_ENV=test mix test --cover
```

### Test Structure
```
apps/hibana/test/
├── controller_test.exs
├── endpoint_test.exs
├── gen_server_test.exs
├── job_test.exs
├── live_view_test.exs
├── otp_cache_test.exs
├── plugin_registry_test.exs
├── plugin_test.exs
├── queue_test.exs
├── router_test.exs
├── web_socket_test.exs
└── test_helper.exs

apps/hibana_plugins/test/
├── api_versioning_test.exs
├── body_parser_test.exs
├── cache_test.exs
├── content_negotiation_test.exs
├── cors_test.exs
├── error_handler_test.exs
├── graceful_shutdown_test.exs
├── graphql_test.exs
├── health_check_test.exs
├── jwt_test.exs
├── live_view_channel_test.exs
├── logger_test.exs
├── metrics_test.exs
├── oauth_test.exs
├── otp_cache_plugin_test.exs
├── rate_limiter_test.exs
├── request_id_test.exs
├── session_test.exs
├── static_test.exs
├── upload_test.exs
└── test_helper.exs
```

## Sample Applications

Sample applications are located in `./sample_apps/` directory. Each app demonstrates different features of the Hibana framework.

### Available Sample Apps

| App | Port | Description |
|-----|------|-------------|
| `hello_world` | 4000 | Basic hello world app |
| `rest_api` | 4001 | REST API with Users and Posts |
| `auth_jwt` | 4002 | JWT authentication demo |
| `websocket_chat` | 4003 | WebSocket chat demo |
| `liveview_counter` | 4004 | LiveView counter demo |
| `background_jobs` | 4005 | Background jobs with Queue |

### Running Sample Apps

```bash
# hello_world (basic routing)
cd sample_apps/hello_world && mix deps.get && mix run

# rest_api (REST endpoints)
cd sample_apps/rest_api && mix deps.get && mix run

# auth_jwt (JWT authentication)
cd sample_apps/auth_jwt && mix deps.get && mix run
# Endpoints:
# POST /auth/login - Login with email/password
# POST /auth/register - Register new user
# GET /protected/profile - Protected endpoint (requires JWT)
# GET /protected/settings - Protected endpoint (requires JWT)

# websocket_chat (WebSocket)
cd sample_apps/websocket_chat && mix deps.get && mix run
# WebSocket: ws://localhost:4003/chat

# liveview_counter (LiveView)
cd sample_apps/liveview_counter && mix deps.get && mix run
# WebSocket: ws://localhost:4004/live/counter

# background_jobs (Queue)
cd sample_apps/background_jobs && mix deps.get && mix run
# Endpoints:
# POST /jobs/send-email - Send email job
# POST /jobs/welcome-email - Welcome email (with delay)
# GET /jobs/stats - Queue statistics
# POST /jobs/clear - Clear queue
```

### Creating a New Sample App

```bash
# Each sample app has this structure:
sample_apps/
└── my_app/
    ├── mix.exs
    ├── config/
    │   └── config.exs
    └── lib/
        ├── my_app/
        │   ├── application.ex
        │   ├── endpoint.ex
        │   ├── router.ex
        │   └── *_controller.ex
        └── my_app.ex
```

## References
- Plug: https://hexdocs.pm/plug
- Phoenix: https://hexdocs.pm/phoenix
- Cowboy: https://hexdocs.pm/cowboy
- ExCoveralls: https://hexdocs.pm/excoveralls