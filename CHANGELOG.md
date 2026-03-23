# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [0.1.0] - 2026-03-23

### Added

- Core framework: Router DSL, Controller, Endpoint with Cowboy
- Plugin system with behavior and runtime registry
- 21 built-in plugins: CORS, RateLimiter, Auth, JWT, OAuth, Static, BodyParser, Session, Logger, ErrorHandler, GraphQL, Cache, OTPCache, HealthCheck, Metrics, APIVersioning, RequestId, ContentNegotiation, Upload, GracefulShutdown, LiveViewChannel
- WebSocket handler with callbacks
- LiveView server-rendered real-time HTML pattern
- Background job queue with retry and delayed execution
- GenServer base module with defaults
- OTP cache with TTL support
- Code reloader for development
- Request validation
- Circuit breaker
- Cron scheduler
- Cluster support with distributed PubSub
- Admin dashboard plugin
- Live dashboard plugin
- Telemetry dashboard plugin
- Project generator: `mix gen.app`
- 6 sample applications
