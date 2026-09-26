# SPEC.md — Git Dashboard (Normative Requirements)

**Plugin:** `code-warlord-dev/git-dashboard`  
**Status:** Living document — update only with ADR when behavior changes  
**Last updated:** 2026-09-26 (M0.5 contract hardening)

Requirements are identified as **REQ-\<area\>-\<nnn\>**.  
Tests that prove them are **T-\<area\>-\<nn\>**.

Areas:  
D = Domain/Schema · A = Aggregator · S = Service · G = GitHub · L = GitLab · T = Gitea · H = Host · W = Widget · U = UI/Panel · N = Notifications · C = Config · P = Plugin scaffold

---

## 1. Domain & Schema (M1)

### REQ-D-001 — ProviderSnapshot unit
A ProviderSnapshot is the sole unit of data produced by one provider (later: one host). It MUST contain at minimum: `provider`, `host`, `account`, `state`, `capabilities`, `counts`, `items`, `activity`, `fetched_at`, `schema_version`.

### REQ-D-002 — Schema version
Every snapshot and aggregated overview MUST carry `schema_version` (integer, start at 1). Consumers MUST tolerate unknown future fields; producers MUST NOT remove fields without a major version bump after 1.0.

### REQ-D-003 — Error taxonomy (ADR-004, ADR-011)
`state` (lifecycle) MUST be one of:  
`ready` | `auth_required` | `rate_limited` | `network_error` | `api_error` | `bad_response` | `loading` | `unavailable`  

**Do not** use `state = "stale"`. Staleness is `data_state` (`fresh` | `stale` | `empty`).

Mapping rules:
- CLI non-zero exit MUST NOT be mapped solely to `auth_required`.
- Rate-limit evidence (CLI message / headers when visible) → `rate_limited`.
- Transport / DNS / timeout → `network_error`.
- Parse / schema mismatch → `bad_response`.
- Prefer structured `error = { code, message, retryable, retry_after?, exit_code? }`.
- Collectors SHOULD run with `LANG=C LC_ALL=C` when invoking CLI to stabilize error text.

### REQ-D-004 — Capability flags (canonical, ADR-009)
`capabilities` is a map of boolean flags. **Canonical keys only:**  
`notifications`, `reviews`, `work_items`, `issues`, `ci`, `contributions`, `mark_read`.  
Forbidden as capability keys: `pull_requests`, `merge_requests`, `actions`, `pipelines` (use `kind` / labels instead).

### REQ-D-005 — Counts (ADR-010)
`counts.attention` MUST equal the number of **distinct `entity_id`** values among items with `attention == true` (not the raw signal count). Other counts (signal-level) optional: `reviews`, `work_items`, `issues`, `ci`, `notifications`.

### REQ-D-006 — Normalized items (ADR-010)
Items in `items` are **signals**. Required fields:  
`id`, `entity_id`, `kind` (`notification` | `review` | `pull_request` | `merge_request` | `issue` | `ci_run`), `title`, `url`, `repo`, `updated_at`, `urgency`, `attention` (bool), `read` (bool where applicable), `provider`, `host`.  
See DATA-MODEL.md §3–4.

### REQ-D-007 — No forge types in domain
Domain types MUST NOT import or reference GitHub / GitLab / Gitea specific SDK types or Noctalia Runtime types.

### REQ-D-008 — Plain data only on state channel
Data published to `noctalia.state` MUST be plain tables / JSON-serializable. No functions, userdata, or closures.

### REQ-D-009 — Stale meta-state (ADR-011)
When serving last-good after failure: keep failure `state`, set `data_state = "stale"`, set `stale_since`. UI MUST show a banner. On `auth_required`, set `data_state = "empty"` and clear privileged items (ADR-012).

### REQ-D-010 — Identity
`account` (login / username) and `host` MUST be present when authenticated; empty or omitted only when `state = auth_required` or `unavailable`.

**Tests:** T-D-001 … (see TRACEABILITY.md).

---

## 2. Aggregator (M1)

### REQ-A-001 — Accept 0..N snapshots
DashboardAggregator MUST accept zero or more ProviderSnapshots and produce a unified overview.

### REQ-A-002 — Attention queue (ADR-010)
Unified `attention[]` is **entity-level** (distinct `entity_id`), merged from all ready/stale-with-data sources, sorted by urgency rank (critical=4 … low=1) then `updated_at` desc.

### REQ-A-003 — Counts aggregation
Top-level counts MUST sum per-provider counts for enabled providers that are not `unavailable`.

### REQ-A-004 — Error isolation
Failure of one provider MUST NOT clear or poison data of other providers. Each provider keeps its last-good or error state independently.

### REQ-A-005 — Capability exposure
Aggregated overview MUST expose the union of capabilities and per-provider capability maps so UI can decide section visibility.

### REQ-A-006 — Filter by provider
UI mode `All | GitHub | GitLab | Gitea` MUST be supported by filtering the aggregated model; filtering MUST NOT require re-fetch.

### REQ-A-007 — No provider string branching in UI contract
Aggregator output MUST be sufficient for UI to render without `if provider == "github"` outside capability / kind checks.

### REQ-A-008 — Schema version on overview
Aggregated overview MUST carry `schema_version` and `fetched_at` (max of constituent snapshots or service time).

### REQ-A-009 — Stale policy
Configurable last-good window (default 30 min). Beyond window, privileged lists MAY be cleared on `auth_required`; on `rate_limited` / `network_error` last-good is preferred with banner.

**M1 implementation notes:** `data_state` is written only by `Schema.apply_success()` /
`Schema.apply_failure()`; the window is `Schema.STALE_WINDOW_SEC` (overridable per
call), `stale_expired = true` marks last-good past the window, and ADR-012 (clear on
`auth_required`) is the stricter rule and wins. Banner input:
`Schema.staleness(snapshot, now)`. Test: `T-A-007`.


### REQ-A-010 — Isolation under dual providers (M4)
When both GitHub and GitLab are enabled, auth failure on one MUST leave the other fully functional.

### REQ-A-011 — Capability honesty (M4+)
If a provider reports `ci = false`, the aggregated model MUST NOT surface an empty CI section as if the feature exists.

### REQ-A-012 — Subset of providers (M5)
Dashboard MUST remain usable with any non-empty subset of enabled providers.

**Tests:** T-A-001 … T-A-008 (merge, isolation, filter, capability hide).

---

## 3. Service (M2)

### REQ-S-001 — Singleton service
Plugin MUST declare a `[[service]]` entry that owns the poll timer and provider orchestration.

### REQ-S-002 — Poll interval
Service MUST use `noctalia.setUpdateInterval` (or equivalent) with a configurable interval (default 120 s). Interval change MUST take effect without restart when `onConfigChanged` is available.

### REQ-S-003 — Argv collectors (ADR-006)
Dynamic CLI invocations MUST use argv-form process execution (not shell-string interpolation).  
**Implementation prerequisite:** pinned Noctalia must expose argv `runAsync` (documented as `plugin_api = 24` in current Noctalia docs). Shell-string form remains forbidden for dynamic arguments even if argv is temporarily unavailable — escalate rather than interpolate.

### REQ-S-004 — Publish to state
After aggregation, service MUST publish the unified overview to `noctalia.state` under a documented key (e.g. `dashboard`).

### REQ-S-005 — Concurrency, timeout, generation (ADR-013)
Providers MAY be refreshed sequentially or with bounded concurrency (max 2 recommended).  
Each refresh has a monotonic `refresh_id`; only results for the current accepted id may publish. Late results discarded.  
Per-provider timeout default 30s; overall refresh budget default 60s. On timeout: `network_error` or keep last-good with `data_state=stale`.

**M1 implementation notes:** `Aggregator:begin_refresh()` issues the monotonic id,
`Aggregator:accepts_generation(id)` and `Aggregator:publish(snapshots, id)` are the only
gate to the published overview (`nil, "stale_generation"` for late results), and
`Aggregator.PROVIDER_TIMEOUT_SEC` / `Aggregator.REFRESH_BUDGET_SEC` expose the defaults.
Test: `T-A-006`.


### REQ-S-006 — Redaction
Collector stderr / stdout that may contain tokens MUST be redacted before any logging.

### REQ-S-007 — Cold start & auth invalidation (ADR-012)
On service start, last-good under the persistent data dir MAY be loaded and published with `data_state=stale` until fresh data arrives — **except** entries that were invalidated on `auth_required` or exceed `last_good_max_age_sec`. Never restore privileged last-good for a source while that source is `auth_required`.

### REQ-S-008 — Enabled providers
Only providers listed in `enabled_providers` setting are invoked.

**Tests:** T-S-001 … T-S-005 (interval, state publish, cold start, redaction).

---

## 4. GitHub Provider (M2–M3)

### REQ-G-001 — CLI backend
GitHubProvider MUST obtain data via `gh` CLI (authenticated session). No plugin-owned PAT store.

### REQ-G-002 — Identity
When authenticated, snapshot MUST include GitHub login and host (`github.com` or Enterprise host).

### REQ-G-003 — Notifications
MUST list unread / actionable notifications with title, repo, url, updated_at, urgency.

### REQ-G-004 — Reviews
MUST list pending review requests assigned to the user.

### REQ-G-005 — Pull requests
MUST list open PRs authored by or assigned to the user (configurable scope later).

### REQ-G-006 — Issues
MUST list open issues assigned to the user.

### REQ-G-007 — Open URL
Every item with a `url` MUST be openable via argv `xdg-open` (or platform equivalent) without shell injection.

### REQ-G-008 — Auth detection
Unauthenticated `gh` MUST produce `state = auth_required` and clear privileged lists.

### REQ-G-009 — Rate limit detection
Rate-limit responses MUST produce `state = rate_limited` (not `auth_required`).

### REQ-G-010 — Network / API errors
Transport failures → `network_error`; other API failures → `api_error` with message.

### REQ-G-011 — Capabilities
GitHubProvider MUST set **canonical** capabilities (notifications, reviews, work_items, issues, ci, contributions, mark_read) consistent with what the code path actually fills.

### REQ-G-012 — Attention count
`counts.attention` MUST count distinct `entity_id` with attention=true (ADR-010).

### REQ-G-013 — Mark single read (M3)
User MUST be able to mark a single notification as read; the action MUST call the appropriate `gh` / API path and update local list optimistically then reconcile.

### REQ-G-014 — Mark all read (M3)
Mark-all-read MUST be supported where the CLI/API allows; confirmation or undo is optional but recommended.

### REQ-G-015 — Optimistic UI
Mark actions MUST update UI immediately; failure MUST roll back and show error.

### REQ-G-016 — No full restart for mark
Mark-read MUST NOT require service restart or full panel close.

### REQ-G-017 — Actions (M3)
Recent workflow runs for relevant repos MAY be listed; controlled by `action_scan_behavior` (off | recent | watched).

### REQ-G-018 — Actions cost control
Default MUST prefer low-cost queries; full org scan is forbidden without explicit setting.

### REQ-G-019 — Actions capability
If CI data is unavailable, capability `ci` MUST be false or section marked unavailable.

### REQ-G-020 — Open Actions URL
Workflow run items MUST open the correct GitHub Actions URL.

### REQ-G-021 — Contributions (M3)
Contribution / activity graph MAY be shown when `include_contributions = true`. Prefer GraphQL or stable CLI; HTML scrape is feature-flagged and may degrade.

### REQ-G-022 — Contributions degradation
If contribution data fails, UI MUST hide the section or show “unavailable”, never a broken calendar.

### REQ-G-023 — Contributions capability
`capabilities.contributions` reflects actual availability.

**Tests:** see TRACEABILITY.md (T-G-*); do not invent range claims.

---

## 5. GitLab Provider (M4) — summary

### REQ-L-001 … REQ-L-010
Analogous to GitHub: `glab`-backed, MRs instead of PRs, pipelines instead of Actions where available, independent error isolation, honest capabilities. Full text mirrors REQ-G structure with GitLab terminology.

---

## 6. Gitea Provider (M5) — summary

### REQ-T-001 … REQ-T-008
`tea`-backed, limited feature set, capability flags strictly honest, no attempt to recreate GitHub-only features.

---

## 7. Multi-host (M6)

### REQ-H-001 — Host dimension
Snapshot identity is `(provider, host, account)`.

### REQ-H-002 — Per-host state
Auth, queues, activity, last-good are per-host.

### REQ-H-003 — Host switch UI
When multiple hosts exist for a provider, UI MUST offer host switch (suggested keys `[` / `]`).

### REQ-H-004 — Isolation
Failure of one host MUST NOT affect another host under the same provider.

### REQ-H-005 — Enterprise / self-hosted
GitHub Enterprise, self-managed GitLab, self-hosted Gitea MUST be representable.

### REQ-H-006 — Default host
Single-host setups MUST work without extra UI chrome.

### REQ-H-007 — Host list in settings
Advanced settings MAY list known hosts; discovery via CLI is preferred.

---

## 8. Widget (M2)

### REQ-W-001 — Badge
Widget MUST show an urgent indicator and/or count derived from aggregated `counts.attention`.

### REQ-W-002 — Click
Primary click MUST toggle the panel via `noctalia.togglePanel("code-warlord-dev/git-dashboard:panel")`.

### REQ-W-003 — No data when unavailable
When all providers are `unavailable` or `auth_required`, badge MUST reflect that (e.g. muted or auth glyph).

### REQ-W-004 — Tooltip
Tooltip SHOULD summarize attention count and highest urgency.

---

## 9. Panel / UI (M2–M3)

### REQ-U-001 — Tabs
Panel MUST support mode tabs: at minimum `All` and one tab per enabled provider.

### REQ-U-002 — Lists
Panel MUST show lists for notifications, reviews, PRs/MRs, issues (and Actions/pipelines when capable).

### REQ-U-003 — Open URL
Selecting / activating an item with url MUST open it via safe argv open.

### REQ-U-004 — Error banners
Each provider section or the All view MUST show explicit banners for non-ready states.

### REQ-U-005 — Capability hide
Sections whose capability is false MUST be hidden or show explicit “unavailable” — never empty fake lists.

### REQ-U-006 — Keyboard foundation
Basic keyboard navigation (arrows, Enter, Escape, Tab between sections) MUST work in M2.

### REQ-U-007 — No provider if-branching
UI code MUST NOT contain `if provider == "github"` except inside capability / kind rendering helpers.

### REQ-U-008 — Placement
Panel placement is user-overridable in Settings → Plugins; default documented in plugin.toml.

### REQ-U-009 — Capture keys
When focused, panel MAY use `capture_keys` for keyboard triage (API 13+).

### REQ-U-010 — Empty states
Empty lists MUST show a clear empty state, not a blank area.

### REQ-U-011 … REQ-U-015 — Full keyboard (M3)
Vim-like subset (j/k, gg, G, / search optional), mark-read key, open-in-browser key, documented in USER.md.

### REQ-U-016 — Multi-provider tabs (M4)
Tabs expand to `All | GitHub | GitLab` (and Gitea later).

### REQ-U-017 — Host switch (M6)
`[` / `]` cycle hosts when multiple present.

---

## 10. System Notifications (M2)

### REQ-N-001 — Channel
High-urgency events MUST be deliverable as system toasts via `noctalia.notify(title, body)` (documented signature), not only inside the panel.

### REQ-N-002 — Urgency levels
Events carry urgency: `low` | `normal` | `high` | `critical`. Mapping is defined in NOTIFICATIONS.md.

### REQ-N-003 — Min urgency setting
User MAY set `notifications.min_urgency`; only events ≥ that level produce toasts.

### REQ-N-004 — Enabled flag
`notifications.enabled = false` suppresses all plugin toasts.

### REQ-N-005 — Dedup
Same item MUST NOT produce repeated toasts within a configurable window (default 30 min).

### REQ-N-006 — Quiet hours
Optional quiet hours suppress toasts (panel and badge still update).

### REQ-N-007 — No sensitive body
Toast body MUST NOT contain tokens, private repo secrets, or full PR diffs.

### REQ-N-008 — Click action (MAY)
If and only if the pinned Runtime API supports notification actions, toast click MAY open the panel or the item URL. Otherwise toasts are informational only. Not a blocker for M2.

**Tests:** T-N-001 … T-N-006.

---

## 11. Config / Settings

### M2 subset (ship with MVP notifications)

### REQ-C-009 — notifications.enabled
Bool, default `true`. Master switch for plugin system toasts.

### REQ-C-010 — notifications.min_urgency
Enum `critical` | `high` | `normal` | `low`, default `high`.

### REQ-C-011 — notifications.dedup_minutes
Integer, default `30`. Same item `id` suppressed within window.

### REQ-C-012 — notifications.quiet_hours
Object `{ start, end }` local time or null. Suppresses toasts only.

### REQ-C-013 — notifications.include_actions
Bool, default `true`. Whether CI failure signals may toast.

### REQ-C-014 — M2 settings declaration
REQ-C-009…013 MUST be declared in `plugin.toml` `[[setting]]` in M2 so Noctalia Settings UI can edit them (not hard-coded only).

### M3+ settings

### REQ-C-001 — Schema
All settings MUST be declared in plugin.toml `[[setting]]` schema so Noctalia Settings UI can edit them.

### REQ-C-002 — enabled_providers
List of provider ids; default `["github"]`.

### REQ-C-003 — poll_interval_sec
Integer, default 120, min 30, max 3600. (May ship earlier in M2 if needed for service.)

### REQ-C-004 — (reserved / superseded by REQ-C-009…013 for notifications)

### REQ-C-005 — include_contributions
Bool, default true.

### REQ-C-006 — action_scan_behavior
`off` | `recent`, default `recent`. Value `watched` is **deferred** until a watched-repository model exists.

### REQ-C-007 — Settings vs persistent data (ADR-007)
User settings MUST be declared in `plugin.toml` and read through Noctalia configuration APIs (`getConfig` / equivalent). Runtime-owned persistent data (last-good, dedup, snooze) MUST be stored under the persistent plugin data directory API, never under the plugin install/runtime dir.

### REQ-C-008 — onConfigChanged
When available, interval, enabled_providers, and notification settings changes MUST apply without full plugin disable/enable.

---

## 12. Plugin scaffold (M2)

### REQ-P-001 — Manifest
`plugin.toml` MUST declare:  
`id = "code-warlord-dev/git-dashboard"`, `plugin_api` matching pinned Noctalia (argv form requires level that documents argv tables, currently 24 in Noctalia docs), entries for service, widget, panel, settings schema, license MIT (or project choice).

### REQ-P-002 — Entry addresses
- `code-warlord-dev/git-dashboard:service`
- `code-warlord-dev/git-dashboard:widget`
- `code-warlord-dev/git-dashboard:panel`

### REQ-P-003 — No invented API
Only documented Noctalia Runtime API calls may be used. Verify against docs.noctalia.dev before code.

---

## 13. Test ID index

**Grammar:** `T-<AREA>-<NNN>` (three-digit), e.g. `T-D-001`.

Defined tests live in `docs/TRACEABILITY.md` (REQ → Test → Milestone → Status).  
Do not claim ranges like “T-G-001 … T-G-015” until each ID has a written case.

Initial planned (M1):

| ID | Covers | Milestone |
|----|--------|-----------|
| T-D-001 | Schema required fields | M1 |
| T-D-002 | Error taxonomy mapping | M1 |
| T-D-003 | Canonical capability keys only | M1 |
| T-D-004 | Urgency rank order | M1 |
| T-D-005 | entity_id + attention distinct count | M1 |
| T-A-001 | Merge two snapshots | M1 |
| T-A-002 | Isolation (one bad source) | M1 |
| T-A-003 | Filter by provider | M1 |
| T-A-004 | Capability hide | M1 |
| T-A-005 | Attention entity dedup | M1 |
| T-A-006 | refresh_id late-result discard | M1 |
| T-A-007 | Last-good window / stale policy | M1 |
| T-A-006 | refresh_id late-result discard | M1 |

M2+ tests (T-S-*, T-G-*, T-N-*) are listed in TRACEABILITY.md when collector contracts freeze.
