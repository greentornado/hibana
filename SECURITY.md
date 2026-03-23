# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in Hibana, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email: security@elixirweb.dev (or create a GitHub Security Advisory)
3. Include: description, steps to reproduce, potential impact
4. We will respond within 48 hours

## Security Defaults

Hibana requires explicit configuration for security-sensitive features:

- **Session**: Requires a secret of at least 32 bytes
- **JWT**: Requires an explicit secret key
- **OAuth**: Requires an explicit JWT secret
- **Admin Dashboard**: Configure `:auth` for production
- **Live Dashboard**: Configure `:auth` for production

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.1.x   | Yes       |
