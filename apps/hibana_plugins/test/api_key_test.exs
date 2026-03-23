defmodule Hibana.Plugins.APIKeyTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.APIKey

  describe "init/1" do
    test "sets default options" do
      opts = APIKey.init([])
      assert opts.keys == []
      assert opts.header == "x-api-key"
      assert opts.query_param == "api_key"
      assert opts.sources == [:header, :query, :bearer]
      assert opts.validator == nil
    end

    test "accepts custom keys and header" do
      opts = APIKey.init(keys: ["key1"], header: "x-custom-key")
      assert opts.keys == ["key1"]
      assert opts.header == "x-custom-key"
    end
  end

  describe "call/2" do
    test "valid key in header passes through" do
      opts = APIKey.init(keys: ["sk_live_abc123"])

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.put_req_header("x-api-key", "sk_live_abc123")
        |> APIKey.call(opts)

      refute conn.halted
      assert conn.assigns[:api_key] == "sk_live_abc123"
    end

    test "invalid key returns 401" do
      opts = APIKey.init(keys: ["sk_live_abc123"])

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.put_req_header("x-api-key", "wrong_key")
        |> APIKey.call(opts)

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["message"] == "Invalid API key"
    end

    test "key in query param" do
      opts = APIKey.init(keys: ["qk_123"])

      conn =
        Plug.Test.conn(:get, "/api/data?api_key=qk_123")
        |> Plug.Conn.fetch_query_params()
        |> APIKey.call(opts)

      refute conn.halted
      assert conn.assigns[:api_key] == "qk_123"
    end

    test "key as bearer token" do
      opts = APIKey.init(keys: ["bearer_key"])

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.fetch_query_params()
        |> Plug.Conn.put_req_header("authorization", "Bearer bearer_key")
        |> APIKey.call(opts)

      refute conn.halted
      assert conn.assigns[:api_key] == "bearer_key"
    end

    test "missing key returns 401" do
      opts = APIKey.init(keys: ["sk_live_abc123"])

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.fetch_query_params()
        |> APIKey.call(opts)

      assert conn.halted
      assert conn.status == 401
      body = Jason.decode!(conn.resp_body)
      assert body["message"] == "Missing API key"
    end

    test "validator function is used when provided" do
      validator = fn key -> key == "custom_valid" end
      opts = APIKey.init(validator: validator, sources: [:header])

      conn =
        Plug.Test.conn(:get, "/api/data")
        |> Plug.Conn.put_req_header("x-api-key", "custom_valid")
        |> APIKey.call(opts)

      refute conn.halted
      assert conn.assigns[:api_key] == "custom_valid"
    end
  end
end
