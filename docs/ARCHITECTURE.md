# ARCHITECTURE.md — Git Dashboard

**Plugin:** `code-warlord-dev/git-dashboard`  
**Target:** Noctalia Shell 5.x  
**Last updated:** 2026-09-26

---

## 1. Core principle

> **UI must not know which CLI or API produced the data.**

Do **not** scatter provider conditionals across UI and service code.  
All branching on forge identity lives inside Providers and the capability model.

---

## 2. Layered architecture

```text
                         ┌─────────────────────┐
                         │     Noctalia UI      │
                         │  widget + panel      │
                         └──────────┬──────────┘
                                    │
                            normalized model
                            + capabilities
                                    │
                         ┌──────────▼──────────┐
                         │   Dashboard Core     │
                         │ aggregation          │
                         │ state                │
                         │ filtering            │
                         │ capabilities         │
                         │ stale policy         │
                         └──────────┬──────────┘
                                    │
                   ┌────────────────┼────────────────┐
                   ▼                ▼                ▼
              GitHubProvider   GitLabProvider   GiteaProvider
                   │                │                │
                  gh               glab             tea
```

---

## 3. Context diagram

```text
┌──────────────────────────────────────────────────────────────────┐
│ Compositor (Niri / other)                                        │
│  • optional keybind → noctalia msg panel-toggle …                │
│  • no plugin code calls compositor IPC                           │
└────────────────────────────┬─────────────────────────────────────┘
                             │ Wayland / layer-shell
┌────────────────────────────▼─────────────────────────────────────┐
│ Noctalia Shell 5                                                 │
│  ┌─────────────┐   state    ┌────────────┐   state   ┌─────────┐ │
│  │  service    │◄──────────►│  widget    │◄─────────►│  panel  │ │
│  │  (core +    │            │  (icon +   │           │  (ui.*) │ │
│  │   providers)│            │   badge)   │           └─────────┘ │
│  └──────┬──────┘            └────────────┘                       │
│         │ runAsync (argv)     notify (toasts)                    │
└─────────┼────────────────────────────────────────────────────────┘
          ▼
┌─────────────────────┐     ProviderSnapshot     ┌──────────────────┐
│ provider collectors │ ───────────────────────► │ Dashboard Core   │
│ (gh / glab / tea)   │                          │ aggregate/state  │
└─────────────────────┘                          │ pluginDataDir    │
          │                                      └──────────────────┘
          ▼
   CLI credential stores (user)
```

---

## 4. Plugin layout

```text
git-dashboard/
├── plugin.toml
├── service.luau                   # owns core + provider orchestration
├── widget.luau
├── panel.luau
├── lib/
│   ├── schema.luau                # ProviderSnapshot v1: normalize + validate (M1)
│   ├── aggregator.luau            # DashboardAggregator: merge / filter / counts (M1)
│   ├── capabilities.luau          # canonical keys, capability-honest sections (M1)
│   ├── errors.luau                # lifecycle error taxonomy (M1, ADR-004/011)
│   ├── urgency.luau               # urgency ranks + ordering (M1, DATA-MODEL §5)
│   ├── badge.luau                 # (M2)
│   ├── format.luau                # (M2)
│   └── notifications.luau         # urgency → toast mapping (M2)
├── providers/
│   ├── github.luau
│   ├── gitlab.luau                # (M4)
│   └── gitea.luau                 # (M5)
├── tests/                         # pure domain tests + fixtures (M1, ADR-015)
│   ├── harness.luau               # minimal assertion harness (no Noctalia)
│   ├── run.luau                   # suite entrypoint
│   ├── fixtures.luau              # plain-data ProviderSnapshots
│   ├── test_schema.luau           # T-D-001 … T-D-005
│   └── test_aggregator.luau       # T-A-001 … T-A-005
├── scripts/
│   └── run-domain-tests.sh        # ADR-015 test entrypoint (local + CI)
├── bin/                           # optional CLI helpers (testable)
│   ├── github-fetch
│   ├── gitlab-fetch
│   └── gitea-fetch
├── translations/en.json
├── thumbnail.webp
└── README.md
```

**M1 status:** `schema`, `aggregator`, `capabilities`, `errors`, `urgency` are
implemented and covered by the `tests/` suite (`scripts/run-domain-tests.sh`).
They import nothing from Noctalia and nothing from a forge SDK (REQ-D-007), and
they are the only modules the UI may depend on.


**Canonical id:** `code-warlord-dev/git-dashboard`  
**Entry addresses:**

- `code-warlord-dev/git-dashboard:service`
- `code-warlord-dev/git-dashboard:widget`
- `code-warlord-dev/git-dashboard:panel`

---

## 5. Layer responsibilities

### 5.1 Provider

Responsible for one forge (and later one host):

- authentication state
- identity / account
- hosts (M6)
- queues / work items
- activity / contributions
- provider-specific metadata
- provider-specific errors
- capabilities set

Produces a **ProviderSnapshot**.

### 5.2 Dashboard Core (Aggregator)

- aggregation of snapshots
- normalization
- unified state for UI
- filtering by provider / host (pure, no re-fetch)
- stale data policy — `Schema.apply_success` / `Schema.apply_failure`, `stale_expired`
- provider capabilities exposure
- common refresh lifecycle — generations (`begin_refresh` / `publish`) and timeouts
- error isolation (one provider down ≠ whole dashboard down)


### 5.3 UI (widget + panel)

Works only with:

- normalized model
- capabilities
- aggregated counts / items
- explicit status per provider/host

Never calls `gh` / `glab` / `tea` directly.  
Never branches on provider string outside capability / kind helpers.

### 5.4 Notifications module

- Maps item urgency + settings → toast or silence
- Dedup window
- Quiet hours
- Calls `noctalia.notify` (or documented equivalent)

---

## 6. Entry roles

### 6.1 Service (singleton)

- Owns poll timer via `noctalia.setUpdateInterval`
- Opens every cycle with `aggregator:begin_refresh()`; results are published only
  through `aggregator:publish(snapshots, refresh_id)` (ADR-013 — late results discarded)
- Invokes providers (sequentially or bounded concurrency)
- Runs collectors via `noctalia.runAsync({...}, cb)` (argv form)
- Classifies failures/timeouts (`Errors.classify`) and applies
  `Schema.apply_failure` per source — `PROVIDER_TIMEOUT_SEC` 30s, `REFRESH_BUDGET_SEC` 60s
- Aggregates ProviderSnapshots → publishes to `noctalia.state`
- Loads/saves last-good under `noctalia.pluginDataDir()`; drops entries older than
  24h (`Schema.should_discard_last_good`)
- Applies notification policy for new high-urgency items


### 6.2 Widget

- Reads aggregated state
- Renders badge / glyph / count
- onClick → `noctalia.togglePanel(...)`
- Tooltip summary

### 6.3 Panel

- Declarative `ui.*` tree
- Tabs: All | per-provider
- Lists driven by filtered model
- Keyboard navigation
- Error banners
- Open URL actions
- Mark-read actions (M3)

---

## 7. Data flow (refresh cycle)

```text
Timer tick
  → refresh_id = aggregator:begin_refresh()                 (ADR-013)
  → for each enabled provider:
      runAsync(collector argv)
        → parse stdout → ProviderSnapshot
        → on success: Schema.apply_success(snapshot, now)
        → on error:   Errors.classify(failure) → Schema.apply_failure(...)
                      (auth/unavailable clear; rate/network keep last-good + banner)
        → on timeout: Aggregator.provider_timed_out → network_error → apply_failure
  → aggregator:publish(snapshots, refresh_id) → overview     (late results discarded)
  → noctalia.state["dashboard"] = overview
  → Notifications.evaluate(new items vs previous)
  → persist last-good (entries older than 24h are not restored)
Widget / Panel watch state → re-render (banner from Schema.staleness)
```


---

## 8. Security boundaries

- Credentials: only CLI stores (`gh auth`, etc.). Plugin never writes tokens.
- Collectors: argv only; no shell interpolation of user/repo names without escaping.
- Logs: redact Authorization headers / tokens from stderr before log.
- State channel: plain data only; no secrets.
- Toasts: no sensitive body content (REQ-N-007).

See `docs/SECURITY.md` for full matrix.

---

## 9. Extension points (post-1.0)

- Additional providers (Bitbucket, Forgejo, …) follow the same Provider interface.
- Custom urgency rules / filters via settings.
- Optional external UI peer (not in v1 scope).
- Webhook / push mode (explicitly out of early scope; requires different security model).

---

## 10. Non-goals (architecture)

- Own secrets manager or PAT UI as primary auth
- Real-time GraphQL subscriptions / webhooks in v1
- Premature generic `Provider<T>` framework with dozens of strategies
- False uniformity of provider APIs
- Compositor-specific code paths
- Mechanical copy-paste of upstream QML/bash without Luau rewrite
