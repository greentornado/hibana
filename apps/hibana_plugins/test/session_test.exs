defmodule Hibana.Plugins.SessionTest do
  use ExUnit.Case, async: true

  @valid_secret "this_is_a_test_secret_key_at_least_32_bytes_long"

  describe "init/1" do
    test "raises without secret" do
      assert_raise ArgumentError, ~r/requires a :secret/, fn ->
        Hibana.Plugins.Session.init([])
      end
    end

    test "raises with short secret" do
      assert_raise ArgumentError, ~r/requires a :secret/, fn ->
        Hibana.Plugins.Session.init(secret: "short")
      end
    end

    test "sets default options with valid secret" do
      opts = Hibana.Plugins.Session.init(secret: @valid_secret)
      assert opts.store == :cookie
      assert opts.key == "hibana_session"
      assert opts.secret == @valid_secret
      assert opts.max_age == 86400 * 30
    end

    test "allows custom options" do
      opts =
        Hibana.Plugins.Session.init(
          store: :cookie,
          key: "my_session",
          secret: @valid_secret,
          max_age: 3600
        )

      assert opts.store == :cookie
      assert opts.key == "my_session"
      assert opts.secret == @valid_secret
      assert opts.max_age == 3600
    end
  end

  describe "call/2" do
    test "adds empty session to conn when no cookie" do
      conn = Plug.Test.conn(:get, "/")

      opts = %{
        key: "test_session",
        secret: @valid_secret,
        max_age: 3600
      }

      result = Hibana.Plugins.Session.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns[:__session__] == %{}
    end

    test "handles malformed cookie" do
      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Conn.put_req_header("cookie", "test_session=invalid")

      opts = %{
        key: "test_session",
        secret: @valid_secret,
        max_age: 3600
      }

      result = Hibana.Plugins.Session.call(conn, opts)
      assert %Plug.Conn{} = result
      assert result.assigns[:__session__] == %{}
    end
  end
end
