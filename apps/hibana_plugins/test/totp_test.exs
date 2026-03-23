defmodule Hibana.Plugins.TOTPTest do
  use ExUnit.Case, async: true

  alias Hibana.Plugins.TOTP

  describe "generate_secret/1" do
    test "generates a base32-encoded secret" do
      secret = TOTP.generate_secret()
      assert is_binary(secret)
      assert byte_size(secret) > 0
      # Should be valid base32 (uppercase letters and digits 2-7)
      assert Regex.match?(~r/^[A-Z2-7]+$/, secret)
    end

    test "generates different secrets each time" do
      s1 = TOTP.generate_secret()
      s2 = TOTP.generate_secret()
      assert s1 != s2
    end
  end

  describe "generate_token/1 and verify/3 round-trip" do
    test "generated token verifies successfully" do
      secret = TOTP.generate_secret()
      now = System.os_time(:second)
      token = TOTP.generate_token(secret, time: now)
      assert :ok == TOTP.verify(secret, token, time: now)
    end

    test "token is a 6-digit string by default" do
      secret = TOTP.generate_secret()
      token = TOTP.generate_token(secret)
      assert String.length(token) == 6
      assert Regex.match?(~r/^\d{6}$/, token)
    end
  end

  describe "verify/3" do
    test "returns error for wrong token" do
      secret = TOTP.generate_secret()
      assert {:error, :invalid_token} = TOTP.verify(secret, "000000", time: 0)
    end

    test "accepts tokens within window" do
      secret = TOTP.generate_secret()
      now = System.os_time(:second)
      # Generate token for previous period
      token = TOTP.generate_token(secret, time: now - 30)
      assert :ok == TOTP.verify(secret, token, time: now, window: 1)
    end
  end

  describe "provisioning_uri/3" do
    test "generates otpauth URI with correct format" do
      secret = TOTP.generate_secret()
      uri = TOTP.provisioning_uri(secret, "user@example.com", issuer: "MyApp")
      assert String.starts_with?(uri, "otpauth://totp/")
      assert String.contains?(uri, "secret=#{secret}")
      assert String.contains?(uri, "issuer=MyApp")

      assert String.contains?(uri, "user@example.com") or
               String.contains?(uri, "user%40example.com")
    end

    test "includes algorithm and digits params" do
      secret = TOTP.generate_secret()
      uri = TOTP.provisioning_uri(secret, "test@test.com")
      assert String.contains?(uri, "algorithm=SHA1")
      assert String.contains?(uri, "digits=6")
      assert String.contains?(uri, "period=30")
    end
  end
end
