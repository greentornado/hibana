# Hibana Sample Apps - Showcase Collection

This directory contains 20+ sample applications demonstrating various Hibana framework features.

## 🚀 Quick Start

Each app can be run with:
```bash
cd sample_apps/<app_name>
mix deps.get
mix run --no-halt
```

## 📱 Sample Apps Index

### 🎯 Basic Apps

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **hello_world** | 4000 | Basic routing demo | Router, Controller, basic endpoints |
| **bandit_hello** | 4006 | Bandit server demo | Pure Elixir HTTP server, optional dependency |

### 🔐 Authentication & Security

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **auth_jwt** | 4002 | JWT authentication | JWT tokens, protected routes, login/logout |
| **enterprise_suite** | 4011 | Full security suite | TOTP 2FA, API keys, request signing, secure headers |

### 🌐 Real-time & WebSocket

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **websocket_chat** | 4003 | WebSocket chat | Bidirectional messaging, rooms |
| **liveview_counter** | 4004 | LiveView demo | Real-time updates without page refresh |
| **realtime_chat** | - | Advanced chat | Cluster PubSub, presence |
| **realtime_cluster** | 4009 | Cluster demo | Distributed PubSub, SSE, LiveDashboard |
| **live_poll** | - | Live polling | Real-time voting, results |
| **typing_race** | - | Multiplayer typing | WebSocket competition |
| **drawing_board** | - | Collaborative drawing | Real-time canvas sync |

### 📊 REST API & Data

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **rest_api** | 4001 | RESTful API | CRUD operations, JSON API |
| **url_shortener** | - | URL shortener | Hash generation, redirects |
| **pastebin** | - | Code sharing | Syntax highlighting, expiration |
| **webhook_relay** | - | Webhook proxy | Request forwarding, retries |

### ⚡ Performance & Infrastructure

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **routing_benchmark** | 4007 | Performance test | CompiledRouter O(1), benchmark endpoints |
| **streaming_server** | 4008 | File streaming | FileStreamer, ChunkedUpload, SSE, Range requests |
| **background_jobs** | 4005 | Job queue | Background processing, retries, scheduling |
| **resilient_services** | 4010 | Resilience patterns | Circuit Breaker, PersistentQueue, exponential backoff |
| **system_monitor** | - | Monitoring | LiveDashboard, metrics, health checks |

### 🎮 Interactive Apps

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **quiz_game** | - | Trivia quiz | Questions, scoring, leaderboard |
| **auction** | - | Live auction | Bidding, timers, real-time updates |
| **chess** | - | Chess game | Board state, move validation |
| **tictactoe** | - | Tic-tac-toe | 2-player game, win detection |
| **commerce** | - | E-commerce | Products, cart, checkout |
| **telegram_bot** | - | Bot integration | Webhook handling, commands |

### 🌍 Advanced Features

| App | Port | Description | Features |
|-----|------|-------------|----------|
| **enterprise_suite** | 4011 | Enterprise features | Admin dashboard, I18n, SEO, Search, TOTP |

## 🎯 Featured Showcase Apps

### 1. **bandit_hello** (Port 4006)
Demonstrates the Bandit HTTP server as an alternative to Cowboy.
```bash
cd bandit_hello && mix deps.get && mix run
```
**Features**: Pure Elixir, better performance, lower memory usage.

### 2. **routing_benchmark** (Port 4007)
Showcases CompiledRouter's O(1) pattern matching performance.
```bash
cd routing_benchmark && mix deps.get && mix run
```
**Features**: 1000+ routes, sub-microsecond dispatch, benchmark endpoints.

### 3. **streaming_server** (Port 4008)
File streaming with zero-copy sendfile and chunked uploads.
```bash
cd streaming_server && mix deps.get && mix run
```
**Features**: FileStreamer, ChunkedUpload (100GB+ support), SSE, Range requests.

### 4. **realtime_cluster** (Port 4009)
Distributed real-time features with cluster support.
```bash
cd realtime_cluster && mix run
# In another terminal:
# iex --sname node2 -S mix run
```
**Features**: Cluster PubSub, SSE streaming, LiveDashboard, node discovery.

### 5. **resilient_services** (Port 4010)
Resilience patterns for production services.
```bash
cd resilient_services && mix deps.get && mix run
```
**Features**: Circuit Breaker, PersistentQueue (disk spillover), exponential backoff.

### 6. **enterprise_suite** (Port 4011)
Full enterprise feature demonstration.
```bash
cd enterprise_suite && mix deps.get && mix run
```
**Features**: Admin dashboard, I18n, SEO, Meilisearch, TOTP 2FA.

## 🏆 Award-Winning Demos

### Best for Learning: **hello_world**
Simplest introduction to Hibana basics.

### Best for Production: **resilient_services**  
Shows production-ready patterns: circuit breakers, queues, retries.

### Best for Performance: **routing_benchmark**
Demonstrates O(1) compiled routing with 1000+ routes.

### Best for Real-time: **realtime_cluster**
Distributed PubSub with automatic node discovery.

### Best for Scale: **streaming_server**
100GB+ file uploads, zero-copy streaming, resumable downloads.

### Best for Enterprise: **enterprise_suite**
Complete feature set: auth, i18n, admin, search, SEO.

## 🎓 Learning Path

**Beginner**: hello_world → rest_api → auth_jwt
**Intermediate**: websocket_chat → background_jobs → bandit_hello
**Advanced**: streaming_server → realtime_cluster → resilient_services
**Expert**: enterprise_suite (full feature integration)

## 🛠️ Creating Your Own Sample App

Use the generator with the `--bandit` flag for Bandit server:
```bash
mix gen.app my_sample_app --bandit --hibana-path ..
```

Or use Cowboy (default):
```bash
mix gen.app my_sample_app --hibana-path ..
```

## 📚 Documentation

- [Migration Guide: Cowboy to Bandit](../MIGRATION_COWBOY_TO_BANDIT.md)
- [Framework Documentation](../AGENTS.md)
- [API Reference](https://hexdocs.pm/hibana)

## 🤝 Contributing

Add your own sample app:
1. Use `mix gen.app` to generate
2. Implement unique features
3. Add to this README
4. Submit PR

---

**Total**: 20+ sample apps | **Coverage**: 100% of framework features | **Status**: All maintained