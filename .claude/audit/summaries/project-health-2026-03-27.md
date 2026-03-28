# Hibana Framework — Project Health Audit

**Date:** 2026-03-27
**Overall Score: 65 / 100 — Grade D (Needs Work)**

## Executive Summary

The Hibana framework compiles cleanly and all 463 tests pass quickly. Dependencies are well-maintained with no vulnerabilities. However, significant gaps exist in test coverage (two entire apps untested), security hardening (no CSRF protection, XSS in dev page), and performance patterns (GenServer bottlenecks in CircuitBreaker and OTPCache). The architecture is generally sound but has an undeclared dependency from core → plugins.

## Score Breakdown

| Category | Score | Grade | Weight | Weighted |
|----------|-------|-------|--------|----------|
| Architecture | 74 | C | 20% | 14.8 |
| Performance | 60 | D | 25% | 15.0 |
| Security | 62 | D | 25% | 15.5 |
| Test Health | 50 | F | 15% | 7.5 |
| Dependencies | 82 | B | 15% | 12.3 |
| **Overall** | **65** | **D** | | **65.1** |

## Critical Issues (Fix Immediately)

### 1. CircuitBreaker executes user functions inside GenServer.call
- **File:** `apps/hibana/lib/hibana/circuit_breaker.ex:163-221`
- **Impact:** All callers serialize behind slow external HTTP calls. Under load, the GenServer mailbox grows unboundedly.
- **Fix:** Execute `fun.()` outside the GenServer, use GenServer only for state transitions.

### 2. RateLimiter has ETS read-then-write race condition
- **File:** `apps/hibana_plugins/lib/hibana/plugins/rate_limiter.ex:140-168`
- **Impact:** Non-atomic `lookup` then `insert` allows over-limit requests under concurrency. This is a correctness bug.
- **Fix:** Use `:ets.update_counter/4` for atomic token decrement.

### 3. Missing CSRF protection
- **Impact:** No CSRF token generation or validation anywhere in the framework. Forms using POST/PUT/DELETE are vulnerable.
- **Fix:** Implement a CSRF plug or integrate `Plug.CSRFProtection`.

### 4. XSS in DevErrorPage
- **File:** `apps/hibana_plugins/lib/hibana/plugins/dev_error_page.ex:139,180-181`
- **Impact:** `conn.request_path` and `conn.query_string` interpolated into HTML without escaping.
- **Fix:** HTML-escape all user-controlled values in error page output.

### 5. Two entire umbrella apps have zero tests
- `hibana_ecto` (6 modules) — no tests at all
- `hibana_generator` (13 Mix tasks) — no tests at all
- 9 core modules also untested (FileStreamer, ChunkedUpload, PersistentQueue, CodeReloader, Pipeline, Cluster, etc.)

## Per-Category Details

### Architecture — 74/100 (C)

| Finding | Severity | Deduction |
|---------|----------|-----------|
| Core app references plugin modules without declaring dependency | Critical | -10 |
| Folder structure diverges from documented plan (flat vs `core/` subdir) | Significant | -13 |
| `TestHelpers` naming suffix | Minor | -3 |
| No circular dependencies | Clean | — |
| Fan-out well-controlled (<5 per module) | Clean | — |
| API surface reasonable (max 18 public funcs/module) | Clean | — |

### Performance — 60/100 (D)

| Finding | Severity | Deduction |
|---------|----------|-----------|
| CircuitBreaker executes user fn inside GenServer.call | Critical | -10 |
| OTPCache serializes all reads through GenServer | High | -10 |
| EventStore routes all ops through GenServer despite ETS | High | -5 |
| Queue.stats() does full ETS table scan twice | Medium | -5 |
| EventStore uses `existing ++ [seq]` — O(n) append | Medium | -5 |
| EventStore regex compiled at runtime per notification | Medium | -5 |
| OTPCache eviction is `hd(Map.keys())` — arbitrary, O(n) | Medium | -5 |
| DistributedRateLimiter stores unbounded timestamp lists | Medium | -5 |
| No N+1 patterns found | Clean | — |

### Security — 62/100 (D)

| Finding | Severity | Deduction |
|---------|----------|-----------|
| No CSRF protection mechanism | Medium | -8 |
| Hardcoded secrets in docs/config/samples, no runtime.exs template | Medium | -10 |
| XSS in DevErrorPage (conn.request_path unescaped) | Medium | -5 |
| Missing security headers (X-Frame-Options, CSP, HSTS) | Low | -5 |
| String.to_atom in tests/generators (copyable anti-pattern) | Low | -10 |
| Timing-safe comparison in API key and TOTP plugins | Clean | — |
| No SQL injection risks | Clean | — |
| Path traversal protections in place (static, uploads) | Clean | — |

### Test Health — 50/100 (F)

| Finding | Severity | Deduction |
|---------|----------|-----------|
| hibana_ecto and hibana_generator entirely untested | Critical | -15 |
| 9 core modules + 1 plugin have no test files | High | -15 |
| 7 Process.sleep calls across 4 test files | Medium | -15 |
| Weak assertions (sse_test, endpoint_test accept any result) | Medium | -4 |
| 3 files use async: false without clear need | Low | -6 |
| search_test.exs leaks Application env (no on_exit cleanup) | Medium | included |
| All 463 tests pass, fast execution (<2s total) | Clean | — |

### Dependencies — 82/100 (B)

| Finding | Severity | Deduction |
|---------|----------|-----------|
| 3 unused deps in hibana_plugins (cowboy, plug_cowboy, mime) | Low | -9 |
| Same 3 deps duplicate umbrella core unnecessarily | Low | -9 |
| No hex.audit vulnerabilities | Clean | — |
| All deps at latest versions | Clean | — |
| Consistent ~> minor version pinning | Clean | — |

## Action Plan

### Immediate (This Week)
1. Fix CircuitBreaker GenServer bottleneck — execute user fn outside handle_call
2. Fix RateLimiter race condition — use `:ets.update_counter`
3. Fix DevErrorPage XSS — HTML-escape conn.request_path and query_string
4. Add `on_exit` cleanup in search_test.exs

### Short-term (This Month)
5. Add CSRF protection plugin
6. Add security headers plugin (X-Frame-Options, CSP, HSTS, etc.)
7. Add tests for FileStreamer, ChunkedUpload, PersistentQueue, Pipeline, Cluster
8. Add basic tests for hibana_ecto and hibana_generator
9. Replace Process.sleep in tests with assert_receive
10. Remove 3 unused deps from hibana_plugins/mix.exs

### Long-term (This Quarter)
11. Refactor OTPCache to use ETS for reads (bypass GenServer serialization)
12. Refactor EventStore to use `:public` or `:protected` ETS tables
13. Fix EventStore O(n) list append → prepend
14. Pre-compile EventStore subscriber regex patterns
15. Add runtime.exs template showing production secret management
16. Replace String.to_atom with String.to_existing_atom in generators
17. Update CLAUDE.md to match actual folder structure (flat, not `core/` subdir)
18. Declare hibana_plugins as optional dep of hibana, or extract shared references

---

*Generated by Hibana Project Health Audit — 5 parallel specialist agents*
