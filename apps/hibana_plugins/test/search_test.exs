defmodule Hibana.Plugins.SearchTest do
  use ExUnit.Case, async: false

  alias Hibana.Plugins.Search

  describe "configure/1" do
    test "stores configuration in application env" do
      assert :ok = Search.configure(url: "http://localhost:7700", api_key: "test-key")
      assert Application.get_env(:hibana_search, :url) == "http://localhost:7700"
      assert Application.get_env(:hibana_search, :api_key) == "test-key"
    end

    test "uses default URL when not specified" do
      Search.configure([])
      assert Application.get_env(:hibana_search, :url) == "http://localhost:7700"
    end
  end

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [path: "/search"]
      assert Search.init(opts) == opts
    end
  end

  describe "call/2 endpoint routing" do
    test "non-search path passes through" do
      opts = Search.init(path: "/search")

      conn =
        Plug.Test.conn(:get, "/other")
        |> Plug.Conn.fetch_query_params()
        |> Search.call(opts)

      refute conn.halted
      assert conn.status == nil
    end

    test "non-GET to search path passes through" do
      opts = Search.init(path: "/search")

      conn =
        Plug.Test.conn(:post, "/search")
        |> Plug.Conn.fetch_query_params()
        |> Search.call(opts)

      refute conn.halted
    end
  end
end
