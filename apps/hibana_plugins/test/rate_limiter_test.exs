defmodule Hibana.Plugins.RateLimiterTest do
  use ExUnit.Case, async: false

  alias Hibana.Plugins.RateLimiter

  setup do
    if :ets.whereis(:rate_limiter) != :undefined do
      :ets.delete(:rate_limiter)
    end

    :ets.new(:rate_limiter, [:set, :named_table, :public, {:read_concurrency, true}])

    on_exit(fn ->
      if :ets.whereis(:rate_limiter) != :undefined do
        :ets.delete(:rate_limiter)
      end
    end)

    :ok
  end

  describe "init/1" do
    test "sets default options" do
      opts = RateLimiter.init([])
      assert opts.max_requests == 100
      assert opts.window_ms == 60_000
      assert opts.storage == :memory
    end

    test "allows custom options" do
      opts = RateLimiter.init(max_requests: 50, window_ms: 30_000, storage: :memory)
      assert opts.max_requests == 50
      assert opts.window_ms == 30_000
      assert opts.storage == :memory
    end

    test "allows custom key_fn" do
      custom_fn = fn conn -> conn.method end
      opts = RateLimiter.init(key_fn: custom_fn)
      assert opts.key_fn == custom_fn
    end
  end

  describe "call/2" do
    test "allows request when under limit" do
      conn = Plug.Test.conn(:get, "/api/users")
      conn = %{conn | remote_ip: {127, 0, 0, 1}}

      opts = %{
        max_requests: 100,
        window_ms: 60_000,
        key_fn: fn c ->
          ip = c.remote_ip |> Tuple.to_list() |> Enum.join(".")
          path = c.path_info |> Enum.join("/")
          "#{ip}:#{path}"
        end
      }

      result = RateLimiter.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.halted == false
    end

    test "blocks request when rate limit exceeded" do
      opts = %{
        max_requests: 1,
        window_ms: 60_000,
        key_fn: fn _ -> "test_key_exceeded" end
      }

      :ets.insert(:rate_limiter, {"test_key_exceeded", 1, System.system_time(:millisecond), 0})

      conn = Plug.Test.conn(:get, "/api/users")

      result = RateLimiter.call(conn, opts)
      assert result.status == 429
      assert result.halted == true
    end
  end

  describe "State" do
    test "creates new state" do
      state = RateLimiter.State.new("test_key", 100, 60_000)
      assert state.key == "test_key"
      assert state.max_requests == 100
      assert state.window_ms == 60_000
      assert state.tokens == 100
      assert state.last_refill != nil
    end
  end
end
