# Hello World

Basic hello world app demonstrating simple routing with Hibana.

## Running

```bash
mix deps.get && mix run
```

Server starts on **port 4000**.

## Endpoints

```bash
# Home page
curl http://localhost:4000/

# Hello greeting
curl http://localhost:4000/hello

# Hello with name
curl http://localhost:4000/hello/world
```
