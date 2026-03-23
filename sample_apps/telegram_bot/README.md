# Telegram Bot — Hibana Sample App

A Telegram bot that receives messages via webhook and responds. Uses the Hibana web framework to serve the webhook endpoint on port 4013.

## Features

- **Webhook endpoint** — Receives Telegram updates via `POST /webhook/:token`
- **Bot commands** — `/start`, `/help`, `/echo <text>`, `/time`, `/dice`, `/weather <city>`, `/menu`
- **Inline keyboard** — `/menu` shows interactive buttons
- **Callback queries** — Handles inline keyboard button presses
- **Webhook management** — `GET /setup` configures the webhook via Telegram API
- **Status & health** — `GET /status` and `GET /health` endpoints
- **Message logging** — Last 100 messages stored in ETS for debugging via `GET /messages`
- **Token verification** — Webhook requests must include the correct bot token in the URL

## Setup

### 1. Create a Bot

Talk to [@BotFather](https://t.me/BotFather) on Telegram and create a new bot. You will receive a bot token like `123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11`.

### 2. Configure the Token

Edit `config/config.exs` and set your bot token:

```elixir
config :telegram_bot,
  bot_token: "YOUR_BOT_TOKEN_HERE"
```

### 3. Start the App

```bash
cd sample_apps/telegram_bot
mix deps.get
mix run --no-halt
```

The server starts on port 4013.

### 4. Set the Webhook

Your server needs to be publicly accessible (use ngrok, Cloudflare Tunnel, etc. for local development).

```bash
# Set webhook
curl "http://localhost:4013/setup?token=YOUR_BOT_TOKEN&url=https://your-domain.com/webhook/YOUR_BOT_TOKEN"
```

### 5. Send Messages

Open your bot in Telegram and send commands like `/start`, `/help`, `/echo hello`, `/dice`, or `/menu`.

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/webhook/:token` | Receive Telegram updates (token must match config) |
| GET | `/setup?token=TOKEN&url=URL` | Set webhook via Telegram API |
| GET | `/status` | Bot status and info |
| GET | `/health` | Health check |
| GET | `/messages` | Recent message log (optional `?limit=N`) |

## Bot Commands

| Command | Description |
|---------|-------------|
| `/start` | Welcome message |
| `/help` | List available commands |
| `/echo <text>` | Echo back your text |
| `/time` | Current UTC time |
| `/dice` | Roll a dice (1-6) |
| `/weather <city>` | Demo weather info |
| `/menu` | Show inline keyboard with options |

## Plugins

- **RequestId** — Adds unique request ID to each request
- **BodyParser** — Parses JSON request bodies
- **ColorLogger** — Pretty-printed colored request logging
- **CORS** — Cross-Origin Resource Sharing headers
- **HealthCheck** — Health endpoint at `/health`
