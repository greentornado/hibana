defmodule Hibana.Plugins.CompressionTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.Compression

  describe "init/1" do
    test "sets default options" do
      opts = Compression.init([])
      assert opts.level == 6
      assert opts.min_size == 860
    end

    test "accepts custom options" do
      opts = Compression.init(level: 9, min_size: 1024)
      assert opts.level == 9
      assert opts.min_size == 1024
    end
  end

  describe "call/2" do
    test "does not halt connection when accept-encoding gzip is present" do
      opts = Compression.init([])

      conn =
        Plug.Test.conn(:get, "/data")
        |> Plug.Conn.put_req_header("accept-encoding", "gzip, deflate")
        |> Compression.call(opts)

      refute conn.halted
    end

    test "does not halt connection without accept-encoding" do
      opts = Compression.init([])

      conn =
        Plug.Test.conn(:get, "/data")
        |> Compression.call(opts)

      refute conn.halted
    end

    test "compresses response body when gzip accepted and body is large enough" do
      opts = Compression.init(min_size: 10)
      large_body = String.duplicate("Hello World! ", 100)

      conn =
        Plug.Test.conn(:get, "/data")
        |> Plug.Conn.put_req_header("accept-encoding", "gzip")
        |> Compression.call(opts)
        |> Plug.Conn.send_resp(200, large_body)

      assert Plug.Conn.get_resp_header(conn, "content-encoding") == ["gzip"]
      assert :zlib.gunzip(conn.resp_body) == large_body
    end

    test "does not compress when body is smaller than min_size" do
      opts = Compression.init(min_size: 10000)
      small_body = "tiny"

      conn =
        Plug.Test.conn(:get, "/data")
        |> Plug.Conn.put_req_header("accept-encoding", "gzip")
        |> Compression.call(opts)
        |> Plug.Conn.send_resp(200, small_body)

      assert Plug.Conn.get_resp_header(conn, "content-encoding") == []
    end
  end
end
