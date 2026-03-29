# Hibana Framework Specification

Complete API reference and usage guide for the Hibana web framework.

## Core Features

### Hibana.Router

Route matching and request dispatch.

```elixir
defmodule MyApp.Router do
  use Hibana.Router

  get "/", PageController, :index
  post "/users", UserController, :create
  get "/users/:id", UserController, :show
end
```

#### DSL Macros

##### `get/3`, `post/3`, `put/3`, `delete/3`, `patch/3`, `options/3`, `head/3`

Define routes for specific HTTP methods.

```elixir
@spec get(path :: String.t(), handler :: module() | fun(), action :: atom()) :: Macro.t()
@spec post(path :: String.t(), handler :: module() | fun(), action :: atom()) :: Macro.t()
@spec put(path :: String.t(), handler :: module() | fun(), action :: atom()) :: Macro.t()
@spec delete(path :: String.t(), handler :: module() | fun(), action :: atom()) :: Macro.t()
@spec patch(path :: String.t(), handler :: module() | fun(), action :: atom()) :: Macro.t()
```

**Parameters:**
- `path` - URL pattern, supports `:` for dynamic segments (e.g., `/users/:id`)
- `handler` - Controller module or inline function
- `action` - Function atom when handler is a module

**Examples:**
```elixir
# Controller-based route
get "/users/:id", UserController, :show

# Inline handler
get "/hello", fn conn ->
  json(conn, %{message: "Hello!"})
end
```

---

### Hibana.CompiledRouter

O(1) constant-time route dispatch via compile-time pattern matching.

```elixir
defmodule MyApp.Router do
  use Hibana.CompiledRouter

  # Static routes
  get "/", PageController, :index
  get "/about", PageController, :about

  # Dynamic segments
  get "/users/:id", UserController, :show
  get "/posts/:category/:slug", PostController, :show

  # Inline handlers
  get "/api/health", fn conn ->
    json(conn, %{status: "ok"})
  end
end
```

#### Performance

Routes compile to BEAM pattern-matching functions at build time:
```elixir
# Compiles to:
def match("GET", ["users", id]), do: {UserController, :show, %{id: id}}
```

**Time complexity:** O(1) regardless of route count

---

### Hibana.Controller

Base controller with response helpers.

```elixir
defmodule MyApp.UserController do
  use Hibana.Controller

  def index(conn) do
    users = MyApp.Users.list()
    json(conn, %{users: users})
  end

  def show(conn) do
    id = conn.params["id"]
    user = MyApp.Users.get(id)
    json(conn, %{user: user})
  end
end
```

#### Response Helpers

##### `json/2`

Send JSON response.

```elixir
@spec json(conn :: Plug.Conn.t(), data :: any()) :: Plug.Conn.t()
@spec json(conn :: Plug.Conn.t(), data :: any(), opts :: keyword()) :: Plug.Conn.t()
```

**Options:**
- `:status` - HTTP status code (default: 200)

```elixir
json(conn, %{user: user}, status: 201)
```

##### `text/2`

Send plain text response.

```elixir
@spec text(conn :: Plug.Conn.t(), data :: String.t()) :: Plug.Conn.t()
text(conn, "Hello, World!")
```

##### `html/2`

Send HTML response.

```elixir
@spec html(conn :: Plug.Conn.t(), data :: String.t()) :: Plug.Conn.t()
html(conn, "<h1>Hello</h1>")
```

##### `redirect/2`

Send redirect response.

```elixir
@spec redirect(conn :: Plug.Conn.t(), location :: String.t()) :: Plug.Conn.t()
redirect(conn, "/login")
```

##### `send_file/2`

Send file download.

```elixir
@spec send_file(conn :: Plug.Conn.t(), path :: String.t()) :: Plug.Conn.t()
send_file(conn, "/path/to/file.pdf")
```

---

### Hibana.Endpoint

HTTP server entry point with Cowboy adapter.

```elixir
defmodule MyApp.Endpoint do
  use Hibana.Endpoint

  plug Hibana.Plugins.Logger
  plug Hibana.Plugins.BodyParser

  plug MyApp.Router
end

# Start in application.ex
children = [
  MyApp.Endpoint
]
```

#### Configuration

```elixir
config :my_app, MyApp.Endpoint,
  port: 4000,
  bind: "0.0.0.0"
```

---

### Hibana.BanditEndpoint

HTTP server with Bandit adapter (alternative to Cowboy).

```elixir
defmodule MyApp.Endpoint do
  use Hibana.BanditEndpoint

  plug MyApp.Router
end
```

---

### Hibana.WebSocket

WebSocket handler behavior.

```elixir
defmodule MyApp.ChatSocket do
  @behaviour Hibana.WebSocket

  @impl true
  def init(conn, opts) do
    {:ok, %{connected: true, room: conn.params["room"]}}
  end

  @impl true
  def handle_in({:text, message}, state) do
    broadcast(state.room, message)
    {[], state}
  end

  @impl true
  def handle_info({:broadcast, msg}, state) do
    {[{:text, msg}], state}
  end
end

# In router:
websocket "/chat/:room", MyApp.ChatSocket, []
```

#### Callbacks

```elixir
@callback init(conn :: Plug.Conn.t(), opts :: any()) :: {:ok, any()} | {:error, any()}
@callback handle_in(message :: any(), state :: any()) :: {list({:text | :binary, any()}), any()}
@callback handle_info(message :: any(), state :: any()) :: {list({:text | :binary, any()}), any()}
@callback terminate(reason :: any(), state :: any()) :: any()
```

---

### Hibana.SSE

Server-Sent Events streaming.

```elixir
defmodule MyApp.EventsController do
  use Hibana.Controller

  def stream(conn) do
    conn = Hibana.SSE.init(conn)
    
    # For production: use stream_loop with limits
    Task.start(fn ->
      Hibana.SSE.stream_loop(conn, 
        max_events: 1000,      # Max 1000 events
        max_duration: 60_000   # Max 60 seconds
      )
    end)
    
    # Send events
    send(self(), {:sse_event, "message", %{data: "Hello"}})
    send(self(), {:sse_event, "message", %{data: "World"}})
    
    Hibana.SSE.stream_loop(conn)
  end
end
```

#### Functions

##### `init/1`

Initialize SSE connection.

```elixir
@spec init(conn :: Plug.Conn.t()) :: Plug.Conn.t()
```

##### `stream/3`

⚠️ **Warning:** Execute without limits. For production, use `stream_loop/2`.

```elixir
@spec stream(conn :: Plug.Conn.t(), fun :: function(), opts :: keyword()) :: Plug.Conn.t()
```

##### `stream_loop/2`

Safe streaming with resource limits.

```elixir
@spec stream_loop(conn :: Plug.Conn.t(), opts :: keyword()) :: Plug.Conn.t()
```

**Options:**
- `:keep_alive` - Keep-alive interval in ms (default: 15_000)
- `:timeout` - Connection timeout in ms (default: :infinity)
- `:max_events` - Maximum events before closing (default: 10_000)
- `:max_duration` - Maximum duration in ms (default: 300_000)

---

### Hibana.Queue

Background job processing with ETS storage.

```elixir
# In application.ex
children = [
  {Hibana.Queue, name: :job_queue}
]

# Enqueue jobs
Hibana.Queue.enqueue(MyApp.EmailJob, %{to: "user@example.com"})
Hibana.Queue.enqueue(MyApp.EmailJob, %{to: "user@example.com"}, delay: 5000, retry: 3)
Hibana.Queue.enqueue_at(MyApp.ReportJob, %{}, future_timestamp)
```

#### Job Module

```elixir
defmodule MyApp.EmailJob do
  @behaviour Hibana.Queue.Job

  @impl true
  def perform(args) do
    # Send email
    :ok
  end
end
```

#### Functions

##### `enqueue/4`

```elixir
@spec enqueue(module :: module(), args :: any(), opts :: keyword(), server :: GenServer.server()) :: {:ok, String.t()} | {:error, any()}
```

**Options:**
- `:delay` - Delay in milliseconds before execution
- `:retry` - Number of retry attempts on failure (default: 3)

##### `enqueue_at/5`

```elixir
@spec enqueue_at(module :: module(), args :: any(), at :: integer(), opts :: keyword(), server :: GenServer.server()) :: {:ok, String.t()} | {:error, any()}
```

---

### Hibana.Job

Simple async job execution.

```elixir
defmodule MyApp.SendEmailJob do
  use Hibana.Job

  @impl true
  def perform(args) do
    # Async work
    :ok
  end
end

# Enqueue
MyApp.SendEmailJob.enqueue(%{to: "user@example.com"})
```

---

### Hibana.OTPCache

GenServer-based in-memory cache with TTL.

```elixir
# In application.ex
children = [
  {Hibana.OTPCache, name: :app_cache}
]

# Usage
Hibana.OTPCache.put(:app_cache, :user_123, user_data, ttl: 60_000)
Hibana.OTPCache.get(:app_cache, :user_123)
Hibana.OTPCache.get_or_compute(:app_cache, :user_123, fn ->
  fetch_from_database()
end, ttl: 60_000)
```

#### Functions

##### `put/4`

```elixir
@spec put(name :: atom(), key :: any(), value :: any(), opts :: keyword()) :: :ok
```

##### `get/2`

```elixir
@spec get(name :: atom(), key :: any()) :: {:ok, any()} | {:error, :not_found}
```

##### `get_or_compute/4`

```elixir
@spec get_or_compute(name :: atom(), key :: any(), fun :: function(), opts :: keyword()) :: {:ok, any()}
```

---

### Hibana.Validator

Request parameter validation with schema.

```elixir
defmodule MyApp.UserController do
  use Hibana.Controller

  def create(conn) do
    schema = %{
      name: [type: :string, required: true],
      age: [type: :integer, min: 0, max: 150],
      email: [type: :string, format: ~r/@/],
      role: [type: :string, in: ["admin", "user"]]
    }

    case Hibana.Validator.validate(conn.body_params, schema) do
      {:ok, validated} ->
        json(conn, %{user: validated}, status: 201)
      
      {:error, errors} ->
        json(conn, %{errors: errors}, status: 422)
    end
  end
end
```

#### Schema Types

- `:string` - String value
- `:integer` - Integer value
- `:float` - Float value
- `:boolean` - Boolean value
- `:list` - List value
- `:map` - Map value

#### Validation Options

- `:required` - Field must be present
- `:min` - Minimum value/length
- `:max` - Maximum value/length
- `:format` - Regex pattern match
- `:in` - Value must be in list

---

### Hibana.CircuitBreaker

Circuit breaker pattern for external service calls.

```elixir
# In application.ex
children = [
  {Hibana.CircuitBreaker, name: :payment_api, threshold: 5, timeout: 30_000}
]

# Usage
case Hibana.CircuitBreaker.call(:payment_api, fn ->
  PaymentGateway.charge(card, amount)
end) do
  {:ok, result} ->
    # Success
    
  {:error, :circuit_open} ->
    # Circuit is open, service unavailable
    
  {:error, reason} ->
    # Call failed
end

# Manual control
Hibana.CircuitBreaker.status(:payment_api)
Hibana.CircuitBreaker.reset(:payment_api)
```

#### States

- `:closed` - Normal operation, requests pass through
- `:open` - Circuit open, requests fail fast
- `:half_open` - Testing if service recovered

#### Functions

##### `call/2`

```elixir
@spec call(name :: atom(), fun :: function()) :: {:ok, any()} | {:error, :circuit_open | any()}
```

##### `status/1`

```elixir
@spec status(name :: atom()) :: %{
  state: :closed | :open | :half_open,
  failure_count: integer(),
  success_count: integer(),
  threshold: integer()
}
```

---

### Hibana.Cron

Cron job scheduler.

```elixir
defmodule MyApp.Scheduler do
  use Hibana.Cron

  # Every 5 minutes
  cron "*/5 * * * *", :cleanup_sessions
  
  # Daily at midnight
  cron "0 0 * * *", :daily_report

  def cleanup_sessions do
    Session.cleanup_expired()
  end

  def daily_report do
    Reports.generate_daily()
  end
end
```

---

### Hibana.EventStore

Event sourcing with projections.

```elixir
# In application.ex
children = [
  Hibana.EventStore
]

# Append events
Hibana.EventStore.append("order-123", [
  %{type: "OrderCreated", data: %{items: [...]}},
  %{type: "OrderPaid", data: %{amount: 100}}
])

# Read events
Hibana.EventStore.read("order-123")

# Subscribe to events
Hibana.EventStore.subscribe("order-123", self())

# Projections
Hibana.EventStore.register_projection(:order_totals, fn event, state ->
  # Reduce function
end, initial_state: %{})
```

---

### Hibana.PersistentQueue

Disk-backed job queue with backpressure.

```elixir
children = [
  {Hibana.PersistentQueue, 
    name: :work_queue,
    max_memory_items: 10_000,
    disk_path: "/tmp/queue",
    concurrency: 5
  }
]

# Enqueue
Hibana.PersistentQueue.enqueue(:work_queue, %{task: "process", data: data})

# Process
{:ok, job} = Hibana.PersistentQueue.dequeue(:work_queue)
# ... process job ...
Hibana.PersistentQueue.ack(:work_queue, job.id)
```

---

### Hibana.FileStreamer

Zero-copy file streaming with Range support.

```elixir
defmodule MyApp.DownloadController do
  use Hibana.Controller

  def download(conn) do
    file = conn.params["file"]
    path = "/uploads/#{file}"
    
    Hibana.FileStreamer.send_file(conn, path)
  end
end
```

#### Features

- `sendfile(2)` syscall for zero-copy transfer
- HTTP Range request support (partial content)
- SHA256 ETag generation
- Path traversal protection

---

### Hibana.ChunkedUpload

Large file upload streaming (100GB+).

```elixir
defmodule MyApp.UploadController do
  use Hibana.Controller

  def upload(conn) do
    Hibana.ChunkedUpload.receive(conn,
      dest: "/uploads",
      max_size: :infinity,
      chunk_size: 8_388_608,
      on_chunk: fn chunk_info ->
        IO.inspect(chunk_info)
      end
    )
  end
end
```

---

## Plugins

### Hibana.Plugins.Logger

Request/response logging.

```elixir
defmodule MyApp.Endpoint do
  use Hibana.Endpoint

  plug Hibana.Plugins.Logger
  plug MyApp.Router
end
```

---

### Hibana.Plugins.BodyParser

JSON and form body parsing.

```elixir
defmodule MyApp.Endpoint do
  use Hibana.Endpoint

  plug Hibana.Plugins.BodyParser,
    limit: 8_000_000,  # 8MB max body size
    parsers: [:json, :urlencoded, :multipart]

  plug MyApp.Router
end
```

---

### Hibana.Plugins.JWT

JWT token authentication.

```elixir
defmodule MyApp.Endpoint do
  use Hibana.Endpoint

  pipeline :api do
    plug Hibana.Plugins.JWT, secret: "secret-key"
  end
end

# Token generation
Hibana.Plugins.JWT.generate_token(%{user_id: 123}, secret: "secret-key")
```

---

### Hibana.Plugins.Auth

Basic HTTP authentication.

```elixir
plug Hibana.Plugins.Auth,
  username: "admin",
  password: "secret"
```

---

### Hibana.Plugins.CORS

Cross-Origin Resource Sharing.

```elixir
plug Hibana.Plugins.CORS,
  origins: ["https://example.com"],
  methods: ["GET", "POST", "PUT", "DELETE"],
  headers: ["Authorization", "Content-Type"]
```

---

### Hibana.Plugins.RateLimiter

Token bucket rate limiting.

```elixir
# Local rate limiting
plug Hibana.Plugins.RateLimiter,
  max_requests: 100,
  window_ms: 60_000,
  key: :ip

# Distributed rate limiting (cluster-wide)
plug Hibana.Plugins.DistributedRateLimiter,
  max_requests: 1000,
  window_ms: 60_000,
  key: :api_key
```

---

### Hibana.Plugins.Session

Cookie-based sessions.

```elixir
plug Hibana.Plugins.Session,
  store: :cookie,
  key: "_my_app_session",
  signing_salt: "salt",
  encryption_salt: "enc-salt"
```

---

### Hibana.Plugins.Static

Static file serving.

```elixir
plug Hibana.Plugins.Static,
  at: "/",
  from: :code.priv_dir(:my_app),
  gzip: true
```

---

### Hibana.Plugins.Cache

Response caching.

```elixir
plug Hibana.Plugins.Cache,
  ttl: 60_000,
  key: fn conn -> conn.request_path end
```

---

### Hibana.Plugins.SecureHeaders

Security headers.

```elixir
plug Hibana.Plugins.SecureHeaders,
  content_security_policy: "default-src 'self'",
  x_frame_options: "DENY",
  x_content_type_options: "nosniff"
```

---

### Hibana.Plugins.GraphQL

GraphQL endpoint.

```elixir
plug Hibana.Plugins.GraphQL,
  schema: MyApp.Schema,
  playground: true  # Enable GraphiQL
```

---

### Hibana.Plugins.HealthCheck

Health endpoint for load balancers.

```elixir
plug Hibana.Plugins.HealthCheck,
  path: "/health"
```

---

### Hibana.Plugins.Metrics

Prometheus-compatible metrics.

```elixir
plug Hibana.Plugins.Metrics,
  path: "/metrics"
```

---

### Hibana.Plugins.APIVersioning

API versioning support.

```elixir
plug Hibana.Plugins.APIVersioning,
  default: "1",
  header: "x-api-version"
```

---

### Hibana.Plugins.RequestId

Request tracing/correlation IDs.

```elixir
plug Hibana.Plugins.RequestId
```

---

### Hibana.Plugins.ErrorHandler

Custom error pages.

```elixir
plug Hibana.Plugins.ErrorHandler,
  not_found: {MyApp.ErrorController, :not_found},
  server_error: {MyApp.ErrorController, :server_error}
```

---

### Hibana.Plugins.GracefulShutdown

Graceful shutdown handling.

```elixir
plug Hibana.Plugins.GracefulShutdown,
  timeout: 30_000
```

---

### Hibana.Plugins.TelemetryDashboard

Live metrics dashboard.

```elixir
plug Hibana.Plugins.TelemetryDashboard,
  path: "/dashboard"
```

---

### Hibana.Plugins.LiveDashboard

System monitoring dashboard.

```elixir
plug Hibana.Plugins.LiveDashboard,
  path: "/system"
```

---

### Hibana.Plugins.Admin

Auto-generated CRUD admin interface.

```elixir
plug Hibana.Plugins.Admin,
  path: "/admin",
  resources: [
    {MyApp.Users.User, MyApp.Users}
  ]
```

---

### Hibana.Plugins.I18n

Internationalization.

```elixir
plug Hibana.Plugins.I18n,
  default_locale: "en",
  locales: ["en", "vi", "ja"]
```

---

### Hibana.Plugins.SEO

SEO meta tags and sitemaps.

```elixir
plug Hibana.Plugins.SEO,
  title: "My App",
  description: "Description",
  generate_sitemap: true
```

---

### Hibana.Plugins.Search

Meilisearch integration.

```elixir
plug Hibana.Plugins.Search,
  host: "http://localhost:7700",
  api_key: "master-key"
```

---

### Hibana.Plugins.TOTP

Two-factor authentication.

```elixir
# Generate secret
{secret, uri} = Hibana.Plugins.TOTP.generate_secret("user@example.com")

# Verify code
Hibana.Plugins.TOTP.verify(code, secret)
```

---

### Hibana.Plugins.RequestSigning

HMAC request signing.

```elixir
plug Hibana.Plugins.RequestSigning,
  algorithm: :sha256,
  secret: "signing-secret"
```

---

### Hibana.Plugins.Compression

Response compression.

```elixir
plug Hibana.Plugins.Compression,
  gzip: true,
  deflate: true,
  min_size: 1024
```

---

## Configuration

### Application Config

```elixir
# config/config.exs
config :my_app, MyApp.Endpoint,
  port: 4000,
  bind: "0.0.0.0"

config :my_app, :features,
  hot_reload: Mix.env() == :dev,
  debug_errors: Mix.env() == :dev
```

### Environment-Specific Config

```elixir
# config/dev.exs
config :my_app, MyApp.Endpoint,
  port: 4000,
  debug_errors: true,
  code_reloader: true

# config/prod.exs
config :my_app, MyApp.Endpoint,
  port: 80,
  debug_errors: false,
  force_ssl: true
```

---

## Testing

### Hibana.TestHelpers

```elixir
defmodule MyApp.UserControllerTest do
  use ExUnit.Case
  use Hibana.TestHelpers

  test "GET /users returns list" do
    conn = get("/users")
    assert conn.status == 200
    assert json_response(conn)["users"]
  end

  test "POST /users creates user" do
    conn = post("/users", %{name: "John", email: "john@example.com"})
    assert conn.status == 201
  end
end
```

---

## Deployment

### Docker

```dockerfile
FROM elixir:1.15-alpine

WORKDIR /app
COPY . .

RUN mix deps.get && mix compile

EXPOSE 4000

CMD ["mix", "run", "--no-halt"]
```

### Release

```bash
# Build release
MIX_ENV=prod mix release

# Run release
_build/prod/rel/my_app/bin/my_app start
```

---

## Performance Tuning

### Compilation Flags

```elixir
# mix.exs
def project do
  [
    elixirc_options: [debug_info: Mix.env() == :dev],
    consolidate_protocols: Mix.env() != :dev
  ]
end
```

### Connection Pooling

```elixir
# lib/my_app/application.ex
children = [
  {Hibana.Endpoint, [port: 4000, acceptors: 100]}
]
```

---

## Troubleshooting

### Common Issues

**ETS table already exists**
```
Check for proper GenServer cleanup in terminate/2 callbacks
```

**FunctionClauseError in controller**
```
Ensure controller functions accept only conn parameter (arity 1)
```

**WebSocket connection refused**
```
Verify handler implements all @callback functions
```

### Debug Mode

```elixir
config :hibana, :debug, true
```

---

## License

MIT License - see LICENSE file
