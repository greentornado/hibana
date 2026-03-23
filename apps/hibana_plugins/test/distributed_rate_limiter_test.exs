defmodule Hibana.Plugins.DistributedRateLimiterTest do
  use ExUnit.Case, async: false

  alias Hibana.Plugins.DistributedRateLimiter

  setup do
    # Clean up ETS table between tests
    case :ets.whereis(:distributed_rate_limiter) do
      :undefined -> :ok
      _ -> :ets.delete_all_objects(:distributed_rate_limiter)
    end

    :ok
  end

  describe "init/1" do
    test "creates ETS table and sets defaults" do
      opts = DistributedRateLimiter.init([])
      assert opts.max_requests == 1000
      assert opts.window_ms == 60_000
      assert is_function(opts.key_fn)
      assert :ets.whereis(:distributed_rate_limiter) != :undefined
    end
  end

  describe "call/2" do
    test "passes requests under the limit" do
      opts = DistributedRateLimiter.init(max_requests: 10, window_ms: 60_000)

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> DistributedRateLimiter.call(opts)

      refute conn.halted
    end

    test "returns rate limit headers" do
      opts = DistributedRateLimiter.init(max_requests: 100, window_ms: 60_000)

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> DistributedRateLimiter.call(opts)

      assert Plug.Conn.get_resp_header(conn, "x-ratelimit-limit") == ["100"]
      [remaining] = Plug.Conn.get_resp_header(conn, "x-ratelimit-remaining")
      assert String.to_integer(remaining) >= 0
    end

    test "blocks requests over the limit" do
      opts = DistributedRateLimiter.init(max_requests: 2, window_ms: 60_000)

      # Make requests up to the limit
      conn1 = Plug.Test.conn(:get, "/api/data") |> DistributedRateLimiter.call(opts)
      refute conn1.halted

      conn2 = Plug.Test.conn(:get, "/api/data") |> DistributedRateLimiter.call(opts)
      refute conn2.halted

      # Third request should be blocked
      conn3 = Plug.Test.conn(:get, "/api/data") |> DistributedRateLimiter.call(opts)
      assert conn3.halted
      assert conn3.status == 429
    end
  end
end
