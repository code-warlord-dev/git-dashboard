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
│   ├── schema.luau                # ProviderSnapshot validation
│   ├── aggregator.luau            # DashboardAggregator
│   ├── capabilities.luau
│   ├── badge.luau
│   ├── format.luau
│   └── notifications.luau         # urgency → toast mapping
├── providers/
│   ├── github.luau
│   ├── gitlab.luau                # (M4)
│   └── gitea.luau                 # (M5)
├── bin/                           # optional CLI helpers (testable)
│   ├── github-fetch
│   ├── gitlab-fetch
│   └── gitea-fetch
├── translations/en.json
├── thumbnail.webp
└── README.md
```

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
- filtering by provider / host
- stale data policy
- provider capabilities exposure
- common refresh lifecycle
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
- Invokes providers (sequentially or bounded concurrency)
- Runs collectors via `noctalia.runAsync({...}, cb)` (argv form)
- Aggregates ProviderSnapshots → publishes to `noctalia.state`
- Loads/saves last-good under `noctalia.pluginDataDir()`
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
  → for each enabled provider:
      runAsync(collector argv)
        → parse stdout → ProviderSnapshot
        → on error: classify state (auth / rate / network / …)
  → Aggregator.merge(snapshots)
  → publish noctalia.state["dashboard"] = overview
  → Notifications.evaluate(new items vs previous)
  → optionally persist last-good
Widget / Panel watch state → re-render
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
