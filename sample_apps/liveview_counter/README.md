# LiveView Counter

LiveView counter demo using Hibana's server-rendered real-time HTML.

## Running

```bash
mix deps.get && mix run
```

Server starts on **port 4004**.

## Endpoints

```bash
# Home page
curl http://localhost:4004/
```

## WebSocket

Connect to `ws://localhost:4004/live/counter` for the LiveView channel.
