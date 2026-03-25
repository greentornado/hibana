defmodule WebhookRelay.Signer do
  @moduledoc """
  HMAC-SHA256 signing for outgoing webhook deliveries.
  Signs the payload with the subscriber's secret key.
  """

  @doc """
  Generate signature headers for an outgoing webhook.
  Returns a map with X-Signature and X-Timestamp headers.
  """
  def sign(body, secret) when is_binary(body) and is_binary(secret) do
    timestamp = System.system_time(:second) |> Integer.to_string()
    signature = compute_signature(timestamp, body, secret)

    %{
      "X-Timestamp" => timestamp,
      "X-Signature" => signature
    }
  end

  @doc """
  Compute HMAC-SHA256 signature for timestamp.body using the secret.
  """
  def compute_signature(timestamp, body, secret) do
    data = "#{timestamp}.#{body}"
    :crypto.mac(:hmac, :sha256, secret, data) |> Base.hex_encode32(case: :lower, padding: false)
  end

  @doc """
  Verify a signature against expected values.
  """
  def verify?(timestamp, body, secret, signature) do
    expected = compute_signature(timestamp, body, secret)
    Plug.Crypto.secure_compare(expected, signature)
  end
end
