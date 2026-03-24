# `Hibana.Plugins.Logger`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/logger.ex#L1)

Request/Response logger plugin.

## Features

- Request timing (start to finish)
- Status code-based log levels
- Configurable log level
- Color-coded output support

## Usage

    # Basic usage
    plug Hibana.Plugins.Logger

    # With custom log level
    plug Hibana.Plugins.Logger, log_level: :debug

## Log Format

    [GET] /users 200 (45ms)
    [POST] /users 201 (120ms)
    [GET] /users/abc 404 (12ms)
    [GET] /api/users 500 (2345ms)

## Log Levels by Status Code

- **200-399**: `:info` level
- **400-499**: `:warning` level (client errors)
- **500+**: `:error` level (server errors)

## Options

- `:log_level` - Minimum log level (default: `:info`)

## Example Output

    [info]  [GET] /api/users 200 (45ms)
    [warn]  [GET] /api/users/invalid 404 (12ms)
    [error] [POST] /api/users 500 (2345ms)

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
