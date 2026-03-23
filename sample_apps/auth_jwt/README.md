# Auth JWT

JWT authentication demo with public and protected endpoints.

## Running

```bash
mix deps.get && mix run
```

Server starts on **port 4002**.

## Endpoints

```bash
# Register a new user
curl -X POST http://localhost:4002/auth/register -H "Content-Type: application/json" -d '{"email":"user@example.com","password":"secret"}'

# Login (returns JWT token)
curl -X POST http://localhost:4002/auth/login -H "Content-Type: application/json" -d '{"email":"user@example.com","password":"secret"}'

# Access protected profile (replace TOKEN with JWT from login)
curl http://localhost:4002/protected/profile -H "Authorization: Bearer TOKEN"

# Access protected settings
curl http://localhost:4002/protected/settings -H "Authorization: Bearer TOKEN"
```
