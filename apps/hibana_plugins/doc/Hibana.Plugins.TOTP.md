# `Hibana.Plugins.TOTP`
[🔗](https://github.com/greentornado/hibana/blob/v0.1.0/lib/hibana/plugins/totp.ex#L1)

Two-factor authentication with TOTP (RFC 6238) and HOTP (RFC 4226).
Compatible with Google Authenticator and similar apps.

## Usage

    secret = Hibana.Plugins.TOTP.generate_secret()
    token = Hibana.Plugins.TOTP.generate_token(secret)
    :ok = Hibana.Plugins.TOTP.verify(secret, token)

    uri = Hibana.Plugins.TOTP.provisioning_uri(secret, "user@example.com", issuer: "MyApp")

# `generate_secret`

Generate a random base32-encoded secret.

# `generate_token`

Generate the current TOTP token for the given secret.

## Options
  - `:period` - time step in seconds (default: 30)
  - `:digits` - number of digits (default: 6)
  - `:algorithm` - hash algorithm (default: :sha)
  - `:time` - override current time (Unix timestamp)

# `hotp`

Generate an HOTP token (RFC 4226).

## Options
  - `:digits` - number of digits (default: 6)
  - `:algorithm` - hash algorithm (default: :sha)

# `provisioning_uri`

Generate an otpauth:// URI for QR code provisioning.

## Options
  - `:issuer` - application name
  - `:period` - time step (default: 30)
  - `:digits` - number of digits (default: 6)
  - `:algorithm` - hash algorithm (default: :sha)

# `verify`

Verify a TOTP token against the secret.

## Options
  - `:period` - time step in seconds (default: 30)
  - `:digits` - number of digits (default: 6)
  - `:algorithm` - hash algorithm (default: :sha)
  - `:window` - number of time steps to check before/after (default: 1)
  - `:time` - override current time (Unix timestamp)

Returns `:ok` on success, `{:error, :invalid_token}` on failure.

---

*Consult [api-reference.md](api-reference.md) for complete listing*
