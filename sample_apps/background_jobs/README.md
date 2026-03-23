# Background Jobs

Background job processing demo using Hibana's Queue system.

## Running

```bash
mix deps.get && mix run
```

Server starts on **port 4005**.

## Endpoints

```bash
# Home page
curl http://localhost:4005/

# Send an email job
curl -X POST http://localhost:4005/jobs/send-email -H "Content-Type: application/json" -d '{"to":"user@example.com"}'

# Send a welcome email (with delay)
curl -X POST http://localhost:4005/jobs/welcome-email -H "Content-Type: application/json" -d '{"to":"user@example.com"}'

# View queue statistics
curl http://localhost:4005/jobs/stats

# Clear the queue
curl -X POST http://localhost:4005/jobs/clear
```
