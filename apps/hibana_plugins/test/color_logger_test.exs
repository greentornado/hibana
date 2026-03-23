defmodule Hibana.Plugins.ColorLoggerTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.ColorLogger

  describe "init/1" do
    test "sets default options" do
      opts = ColorLogger.init([])
      assert opts.level == :info
      assert opts.include_params == true
      assert opts.include_headers == false
    end

    test "accepts custom level" do
      opts = ColorLogger.init(level: :debug, include_params: false)
      assert opts.level == :debug
      assert opts.include_params == false
    end
  end

  describe "call/2" do
    test "does not halt the connection" do
      opts = ColorLogger.init([])

      conn =
        Plug.Test.conn(:get, "/hello")
        |> ColorLogger.call(opts)

      refute conn.halted
    end

    test "logs request on send" do
      opts = ColorLogger.init(level: :debug)

      conn =
        Plug.Test.conn(:get, "/hello")
        |> Plug.Conn.fetch_query_params()
        |> ColorLogger.call(opts)
        |> Plug.Conn.send_resp(200, "ok")

      assert conn.status == 200
    end
  end
end
