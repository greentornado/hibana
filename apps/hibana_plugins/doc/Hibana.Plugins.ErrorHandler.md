# `Hibana.Plugins.ErrorHandler`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/error_handler.ex#L1)

Custom error handler plugin for HTTP errors.

## Features

- Custom 404 (Not Found) handlers
- Custom 500 (Server Error) handlers
- HTML and JSON response formats
- Pluggable error rendering functions

## Usage

    # Basic usage
    plug Hibana.Plugins.ErrorHandler

    # With custom handlers
    plug Hibana.Plugins.ErrorHandler,
      not_found: &my_not_found_handler/1,
      server_error: &my_error_handler/1

## Options

- `:not_found` - Custom 4xx error handler function
- `:server_error` - Custom 5xx error handler function

## Handler Functions

Custom handler receives the conn:

    def my_not_found_handler(conn) do
      json(conn, %{error: "Resource not found"})
    end

    def my_error_handler(conn) do
      json(conn, %{error: "Internal server error"})
    end

## Default Responses

**404 Not Found:**
    HTTP 404
    <html><body><h1>404 - Not Found</h1></body></html>

**500 Server Error:**
    HTTP 500
    <html><body><h1>500 - Internal Server Error</h1></body></html>

# `start_link`

---

*Consult [api-reference.md](api-reference.md) for complete listing*
