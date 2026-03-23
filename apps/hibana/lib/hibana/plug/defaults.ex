defmodule Hibana.Plug.Defaults do
  @moduledoc """
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
  """

  @behaviour Plug

  import Plug.Conn

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    conn = fetch_query_params(conn)
    assign(conn, :params, conn.params)
  end
end
