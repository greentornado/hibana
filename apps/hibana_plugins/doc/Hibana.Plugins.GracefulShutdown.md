# `Hibana.Plugins.GracefulShutdown`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/graceful_shutdown.ex#L1)

Graceful shutdown plugin for zero-downtime deployments.

## Features

- Configurable shutdown timeout
- Request draining support
- Process exit signaling
- Header signaling for load balancers

## Usage

    # Basic usage
    plug Hibana.Plugins.GracefulShutdown

    # Custom timeout
    plug Hibana.Plugins.GracefulShutdown,
      timeout: 60_000,
      drain: true

## Options

- `:timeout` - Shutdown timeout in ms (default: `30_000`)
- `:drain` - Enable request draining (default: `true`)

## Module Functions

### start_shutdown/1
Initiate graceful shutdown:

    Hibana.Plugins.GracefulShutdown.start_shutdown(30_000)

### drain_requests/1
Wait for in-flight requests to complete:

    Hibana.Plugins.GracefulShutdown.drain_requests(30_000)

### notify_shutdown/0
Signal shutdown to all processes:

    Hibana.Plugins.GracefulShutdown.notify_shutdown()

## Shutdown Sequence

1. Receive SIGTERM
2. Stop accepting new requests
3. Drain existing requests (wait for completion)
4. Timeout if requests take too long
5. Exit process

## Response Header

Adds header to indicate shutdown capability:

    X-Shutdown-Timeout: 30000

# `before_send`

# `drain_requests`

Drain remaining requests before shutdown.

# `notify_shutdown`

Notify shutdown to all processes.

# `start_link`

# `start_shutdown`

Start graceful shutdown process.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
