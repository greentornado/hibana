defmodule Hibana.Plugins.RequestSigningTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.RequestSigning

  describe "sign/1" do
    test "produces a hex-encoded string" do
      signature =
        RequestSigning.sign(
          method: "POST",
          path: "/api/data",
          body: ~s({"key":"value"}),
          secret: "my-secret",
          timestamp: "1700000000"
        )

      assert is_binary(signature)
      assert Regex.match?(~r/^[0-9a-f]+$/, signature)
    end

    test "same inputs produce same signature" do
      opts = [method: "GET", path: "/test", secret: "secret", timestamp: "12345"]
      assert RequestSigning.sign(opts) == RequestSigning.sign(opts)
    end

    test "different secrets produce different signatures" do
      base = [method: "GET", path: "/test", timestamp: "12345"]
      s1 = RequestSigning.sign(Keyword.put(base, :secret, "secret1"))
      s2 = RequestSigning.sign(Keyword.put(base, :secret, "secret2"))
      assert s1 != s2
    end
  end

  describe "sign_headers/1" do
    test "returns header list with signature and timestamp" do
      headers =
        RequestSigning.sign_headers(
          method: "POST",
          path: "/api/data",
          body: "",
          secret: "my-secret",
          timestamp: "1700000000"
        )

      assert is_list(headers)
      assert {"x-signature", _sig} = List.keyfind(headers, "x-signature", 0)
      assert {"x-timestamp", "1700000000"} = List.keyfind(headers, "x-timestamp", 0)
    end
  end

  describe "sign + verify round-trip" do
    test "verify_signature returns :ok for valid signature" do
      timestamp = to_string(System.os_time(:second))

      signature =
        RequestSigning.sign(
          method: "POST",
          path: "/api/data",
          body: "hello",
          secret: "shared-secret",
          timestamp: timestamp
        )

      assert :ok =
               RequestSigning.verify_signature(
                 signature: signature,
                 method: "POST",
                 path: "/api/data",
                 body: "hello",
                 secret: "shared-secret",
                 timestamp: timestamp
               )
    end

    test "verify_signature returns error for tampered signature" do
      timestamp = to_string(System.os_time(:second))

      assert {:error, :invalid_signature} =
               RequestSigning.verify_signature(
                 signature: "badhex",
                 method: "POST",
                 path: "/api/data",
                 body: "hello",
                 secret: "shared-secret",
                 timestamp: timestamp
               )
    end
  end

  describe "init/1" do
    test "raises without :secret option" do
      assert_raise ArgumentError, ~r/requires :secret/, fn ->
        RequestSigning.init([])
      end
    end

    test "sets default max_age" do
      opts = RequestSigning.init(secret: "test")
      assert Keyword.get(opts, :max_age) == 300
    end
  end
end
