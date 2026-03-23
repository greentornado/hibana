defmodule Hibana.Plugins.TOTP do
  @moduledoc """
  Two-factor authentication with TOTP (RFC 6238) and HOTP (RFC 4226).
  Compatible with Google Authenticator and similar apps.

  ## Usage

      secret = Hibana.Plugins.TOTP.generate_secret()
      token = Hibana.Plugins.TOTP.generate_token(secret)
      :ok = Hibana.Plugins.TOTP.verify(secret, token)

      uri = Hibana.Plugins.TOTP.provisioning_uri(secret, "user@example.com", issuer: "MyApp")
  """

  import Bitwise

  @default_digits 6
  @default_period 30
  @default_algorithm :sha
  @default_secret_length 20

  @doc """
  Generate a random base32-encoded secret.
  """
  def generate_secret(length \\ @default_secret_length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(padding: false)
  end

  @doc """
  Generate the current TOTP token for the given secret.

  ## Options
    - `:period` - time step in seconds (default: 30)
    - `:digits` - number of digits (default: 6)
    - `:algorithm` - hash algorithm (default: :sha)
    - `:time` - override current time (Unix timestamp)
  """
  def generate_token(secret, opts \\ []) do
    period = Keyword.get(opts, :period, @default_period)
    time = Keyword.get(opts, :time, System.os_time(:second))
    counter = div(time, period)

    hotp(secret, counter, opts)
  end

  @doc """
  Verify a TOTP token against the secret.

  ## Options
    - `:period` - time step in seconds (default: 30)
    - `:digits` - number of digits (default: 6)
    - `:algorithm` - hash algorithm (default: :sha)
    - `:window` - number of time steps to check before/after (default: 1)
    - `:time` - override current time (Unix timestamp)

  Returns `:ok` on success, `{:error, :invalid_token}` on failure.
  """
  def verify(secret, token, opts \\ []) do
    period = Keyword.get(opts, :period, @default_period)
    window = Keyword.get(opts, :window, 1)
    time = Keyword.get(opts, :time, System.os_time(:second))
    counter = div(time, period)

    token = String.trim(to_string(token))

    valid? =
      Enum.any?(-window..window, fn offset ->
        expected = hotp(secret, counter + offset, opts)
        constant_time_compare(expected, token)
      end)

    if valid?, do: :ok, else: {:error, :invalid_token}
  end

  @doc """
  Generate an otpauth:// URI for QR code provisioning.

  ## Options
    - `:issuer` - application name
    - `:period` - time step (default: 30)
    - `:digits` - number of digits (default: 6)
    - `:algorithm` - hash algorithm (default: :sha)
  """
  def provisioning_uri(secret, account, opts \\ []) do
    issuer = Keyword.get(opts, :issuer, "Hibana")
    period = Keyword.get(opts, :period, @default_period)
    digits = Keyword.get(opts, :digits, @default_digits)
    algorithm = Keyword.get(opts, :algorithm, @default_algorithm)

    label =
      if issuer do
        "#{URI.encode(issuer)}:#{URI.encode(account)}"
      else
        URI.encode(account)
      end

    params =
      [
        {"secret", secret},
        {"issuer", issuer},
        {"algorithm", algorithm_name(algorithm)},
        {"digits", to_string(digits)},
        {"period", to_string(period)}
      ]
      |> Enum.map(fn {k, v} -> "#{k}=#{URI.encode(to_string(v))}" end)
      |> Enum.join("&")

    "otpauth://totp/#{label}?#{params}"
  end

  @doc """
  Generate an HOTP token (RFC 4226).

  ## Options
    - `:digits` - number of digits (default: 6)
    - `:algorithm` - hash algorithm (default: :sha)
  """
  def hotp(secret, counter, opts \\ []) do
    digits = Keyword.get(opts, :digits, @default_digits)
    algorithm = Keyword.get(opts, :algorithm, @default_algorithm)

    key = decode_secret(secret)
    counter_bytes = <<counter::unsigned-big-integer-size(64)>>

    hmac = :crypto.mac(:hmac, algorithm, key, counter_bytes)

    # Dynamic truncation (RFC 4226 Section 5.4)
    offset = :binary.at(hmac, byte_size(hmac) - 1) &&& 0x0F

    <<_::binary-size(offset), code::unsigned-big-integer-size(32), _::binary>> = hmac

    code = (code &&& 0x7FFFFFFF) |> rem(power(10, digits))

    code
    |> Integer.to_string()
    |> String.pad_leading(digits, "0")
  end

  # --- Private ---

  defp decode_secret(secret) do
    # Handle base32 encoded secrets
    secret_upper = String.upcase(secret)

    # Add padding if needed
    padded =
      case rem(byte_size(secret_upper), 8) do
        0 -> secret_upper
        n -> secret_upper <> String.duplicate("=", 8 - n)
      end

    case Base.decode32(padded) do
      {:ok, decoded} -> decoded
      :error -> secret
    end
  end

  defp power(base, exp) do
    :math.pow(base, exp) |> round()
  end

  defp algorithm_name(:sha), do: "SHA1"
  defp algorithm_name(:sha256), do: "SHA256"
  defp algorithm_name(:sha512), do: "SHA512"
  defp algorithm_name(other), do: to_string(other)

  defp constant_time_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp constant_time_compare(a, b) do
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    Enum.zip(a_bytes, b_bytes)
    |> Enum.reduce(0, fn {x, y}, acc -> Bitwise.bor(acc, Bitwise.bxor(x, y)) end)
    |> Kernel.==(0)
  end
end
