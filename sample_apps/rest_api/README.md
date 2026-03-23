# REST API

REST API demo with Users and Posts CRUD endpoints.

## Running

```bash
mix deps.get && mix run
```

Server starts on **port 4001**.

## Endpoints

```bash
# List users
curl http://localhost:4001/api/users

# Get a user
curl http://localhost:4001/api/users/1

# Create a user
curl -X POST http://localhost:4001/api/users -H "Content-Type: application/json" -d '{"name":"Alice","email":"alice@example.com"}'

# Update a user
curl -X PUT http://localhost:4001/api/users/1 -H "Content-Type: application/json" -d '{"name":"Bob"}'

# Delete a user
curl -X DELETE http://localhost:4001/api/users/1

# List posts
curl http://localhost:4001/api/posts

# Get a post
curl http://localhost:4001/api/posts/1

# Create a post
curl -X POST http://localhost:4001/api/posts -H "Content-Type: application/json" -d '{"title":"My Post","body":"Hello"}'
```
