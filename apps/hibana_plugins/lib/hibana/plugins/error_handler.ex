defmodule Hibana.Plugins.ErrorHandler do
  @moduledoc """
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
  """

  use Hibana.Plugin
  import Plug.Conn

  @impl true
  def init(opts) do
    %{
      not_found: Keyword.get(opts, :not_found, :default),
      server_error: Keyword.get(opts, :server_error, :default)
    }
  end

  @impl true
  def call(conn, %{not_found: not_found_handler, server_error: server_error_handler}) do
    conn
    |> assign(:error_not_found, not_found_handler)
    |> assign(:error_server_error, server_error_handler)
  end

  @impl true
  def before_send(%{status: status} = conn, _opts) when status >= 400 and status < 500 do
    handler = Map.get(conn.assigns, :error_not_found, :default)
    apply_handler(conn, handler, :not_found)
  end

  @impl true
  def before_send(%{status: status} = conn, _opts) when status >= 500 do
    handler = Map.get(conn.assigns, :error_server_error, :default)
    apply_handler(conn, handler, :server_error)
  end

  @impl true
  def before_send(conn, _opts), do: conn

  defp apply_handler(conn, :default, :not_found), do: default_not_found(conn)
  defp apply_handler(conn, :default, :server_error), do: default_server_error(conn)
  defp apply_handler(conn, fun, _type) when is_function(fun, 1), do: fun.(conn)
  defp apply_handler(conn, {mod, fun}, _type), do: apply(mod, fun, [conn])
  defp apply_handler(conn, {mod, fun, args}, _type), do: apply(mod, fun, [conn | args])

  defp default_not_found(conn) do
    %{conn | resp_body: "<html><body><h1>404 - Not Found</h1></body></html>"}
    |> put_resp_content_type("text/html")
  end

  defp default_server_error(conn) do
    %{conn | resp_body: "<html><body><h1>500 - Internal Server Error</h1></body></html>"}
    |> put_resp_content_type("text/html")
  end
end
