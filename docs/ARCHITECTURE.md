# Optly architecture

This document describes how the Optly clients, shared contracts, and Supabase-backed backend fit together.

## System overview (text diagram)

```
┌─────────────────┐     ┌─────────────────┐
│   iOS (Swift)   │     │ Android (Kotlin) │
│  On-device AI   │     │  On-device AI    │
│  HealthKit      │     │  Health Connect  │
└────────┬────────┘     └────────┬─────────┘
         │                       │
         │    HTTPS + JWT        │
         └───────────┬───────────┘
                     ▼
         ┌───────────────────────┐
         │ Supabase (Postgres)   │
         │ Auth · RLS · Storage  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │ Edge Functions (Deno) │
         │ Briefings · insights  │
         └───────────┬───────────┘
                     │
                     ▼
         ┌───────────────────────┐
         │ External AI / APIs      │
         │ (e.g. Claude, Plaid)    │
         └───────────────────────┘
```

The canonical HTTP surface for product features is documented in `shared/api/openapi.yaml` (aligned with Swift models under `ios/Optly/Models/`). Supabase Auth issues JWTs; Edge Functions enforce auth and business rules.

## Data flow

1. **Local first:** The apps read and write user state in on-device stores and run lightweight inference for immediate UX (see `OnDeviceAIEngine` on each platform).
2. **Sync up:** Structured entities (habits, subscriptions, health aggregates, focus sessions) sync to Postgres via the API or direct Supabase client calls, subject to row-level security.
3. **Cloud augmentation:** Edge Functions aggregate rows, call external AI where allowed, and persist derived artifacts (for example cached `daily_briefings` JSON matching the `DailyBriefing` shape).
4. **Pull down:** Clients fetch briefings, finance rollups, and insight cards; the UI merges server data with local context (calendar, notifications).

## On-device vs cloud AI (decision tree)

- **On-device** when: latency must be instant, data is sensitive or already local, the task is small (ranking, copy tweaks, simple scoring), or the network is unavailable.
- **Cloud (Edge + model API)** when: the model needs broad cross-domain context stored server-side, output must be consistent across devices, or the computation exceeds on-device budgets.
- **Hybrid:** On-device proposes; cloud validates or enriches with server-only signals (aggregated spend, cohort-safe patterns). Never send raw secrets (bank credentials, full message content) to models without explicit user consent and minimization.

## Security and privacy model

- **Authentication:** Supabase Auth; clients send short-lived JWTs. Edge Functions verify the JWT and derive `auth.uid()` for data access.
- **Authorization:** Postgres row-level security restricts rows to the owning user. Service role keys stay server-side only.
- **Transport:** TLS for all API traffic. Pinning may be added in clients for high-risk deployments.
- **Secrets:** API keys for third parties live in Edge Function secrets / CI, not in mobile binaries beyond public anon keys where required.
- **Health and finance:** Minimize fields sent to the server; prefer aggregates and user-approved scopes. See `docs/PRIVACY.md`.

## Sync architecture

- **Conflict handling:** Last-write-wins per entity with `updated_at`, or explicit merge for append-only structures (for example habit `completions`).
- **Offline:** Clients queue mutations; on reconnect, replay with idempotency keys where the API supports them (for example health sync batches).
- **Observability:** Log sync failures client-side; server returns rate-limit headers (`X-RateLimit-*`) so clients can backoff.

## API rate limiting strategy

- **Goals:** Protect Edge Functions and upstream LLM quotas; fair use per user and per IP on unauthenticated routes.
- **Headers:** All responses expose `X-RateLimit-Limit`, `X-RateLimit-Remaining`, and `X-RateLimit-Reset`. `429` responses include `Retry-After`.
- **Tiers:** Stricter limits on expensive routes (`POST /subscriptions/scan`, `POST /health/sync`, AI-backed reads). Authenticated users get higher ceilings than anonymous auth endpoints.
- **Implementation:** Edge middleware or Supabase rate-limit tables (see `backend/supabase/functions/_shared/rate-limit.ts`) record sliding-window counters keyed by `user_id` or IP.

## Database schema overview

Core tables (see `backend/supabase/migrations/001_initial_schema.sql`):

| Table | Purpose |
|--------|---------|
| `public.users` | Profile row linked to `auth.users`; preferences JSON |
| `public.subscriptions` | Recurring charges, usage scores, AI recommendation |
| `public.habits` | Habit definition, streak, completions JSONB |
| `public.health_data` | Daily aggregates (steps, sleep, energy) |
| `public.finance_snapshots` | Monthly rollup, expenses by category JSONB |
| `public.focus_sessions` | Focus blocks and productivity score |
| `public.daily_briefings` | Cached briefing document (JSONB, app-shaped) |
| `public.insight_cards` | Insight cards with `acted_on` and metadata |

RLS policies grant each authenticated user CRUD only on their own rows. Triggers maintain `public.users` when `auth.users` is created.
