# DATA-MODEL.md — ProviderSnapshot & Aggregated Overview

**Last updated:** 2026-09-26 (M0.5 contract hardening)  
**Status:** Normative for M1+

---

## 1. Principles

1. **ProviderSnapshot** is the unit of data from one **source** = `(provider, host, account)`.
2. **Dashboard Core** aggregates snapshots into a unified overview for UI.
3. **Capability-aware** — UI never assumes a section exists.
4. **Canonical capability vocabulary is provider-neutral** (ADR-009).
5. **Attention is entity-based with signals** (ADR-010) — one PR is one attention entity even if it has notification + review + CI signals.
6. **Plain data only** on `noctalia.state` (no functions).
7. **Schema version** for forward compatibility.
8. Do **not** force false uniformity of forge APIs beyond the canonical model.

---

## 2. Canonical capability vocabulary (ADR-009)

Capabilities are **provider-neutral**. Provider-specific terms appear only in `kind`, labels, and presentation metadata.

| Capability key | Meaning |
|----------------|---------|
| `notifications` | Inbox / notification list |
| `reviews` | Pending review requests |
| `work_items` | PRs **or** MRs (open work the user owns / is assigned) |
| `issues` | Assigned / relevant issues |
| `ci` | Actions / pipelines / workflow runs |
| `contributions` | Activity / contribution graph |
| `mark_read` | Can mark notifications (or equivalent) as read |

**Forbidden in capability map:** `pull_requests`, `merge_requests`, `actions`, `pipelines` as capability keys.  
Those terms may appear only as `kind` values or UI labels derived from `kind` + provider.

```lua
capabilities = {
    notifications = true,
    reviews = true,
    work_items = true,
    issues = true,
    ci = true,
    contributions = true,
    mark_read = true,
}
```

**Input aliasing (M1).** A provider that reports a forge-specific key is
translated on input and the translation is reported back to the caller, so
nothing is hidden:

| Provider key in | Canonical key out |
|-----------------|-------------------|
| `pull_requests`, `merge_requests` | `work_items` |
| `actions`, `pipelines` | `ci` |

Output is canonical only: non-canonical and unknown keys never reach the model.
If two aliases disagree for the same canonical key, `true` wins — the result must
not depend on table iteration order (`lib/capabilities.luau`).


---

## 3. WorkItem identity & attention (ADR-010)

### 3.1 Identifiers

| Field | Role |
|-------|------|
| `id` | **Signal / event id** — unique per notification thread, review request event, CI run, etc. Used for mark-read, dedup toasts, list keys. Format: `"{provider}:{kind}:{native_id}"` |
| `entity_id` | **Attention entity** — stable id of the underlying work object. Format: `"{provider}:{entity_kind}:{host}/{repo}#{number}"` e.g. `github:pr:github.com/org/repo#42` |
| `kind` | Signal type (see §4) |
| `attention` | bool — whether this signal contributes to the attention queue |

### 3.2 Attention counting rules

1. **Badge / `counts.attention`** = number of **distinct `entity_id`** values among items where `attention == true` and the source is ready (or stale-with-data).
2. One PR that appears as notification + review + failing CI still counts as **1** toward attention.
3. The **attention list** (`attention[]` in overview) is a list of **entities**, each carrying the highest urgency among its signals and a list of signal ids.
4. Mark-read of a notification signal does not necessarily clear the entity if a review signal remains.

### 3.3 Example

```lua
-- Three signals, one entity → attention contribution = 1
{
  id = "github:notification:abc",
  entity_id = "github:pr:github.com/org/repo#42",
  kind = "notification",
  urgency = "high",
  attention = true,
},
{
  id = "github:review:def",
  entity_id = "github:pr:github.com/org/repo#42",
  kind = "review",
  urgency = "high",
  attention = true,
},
{
  id = "github:ci_run:ghi",
  entity_id = "github:pr:github.com/org/repo#42",
  kind = "ci_run",
  urgency = "high",
  attention = true,
}
```

---

## 4. WorkItem kinds

| kind | Maps to capability | Notes |
|------|--------------------|-------|
| `notification` | notifications | |
| `review` | reviews | |
| `pull_request` | work_items | GitHub / Gitea |
| `merge_request` | work_items | GitLab |
| `issue` | issues | |
| `ci_run` | ci | GitHub Actions run, GitLab/Gitea pipeline |

UI section labels: derive from kind + provider (e.g. "Pull requests" vs "Merge requests").

---

## 5. Urgency rank (normative)

| urgency | rank |
|---------|-----:|
| `critical` | 4 |
| `high` | 3 |
| `normal` | 2 |
| `low` | 1 |

Sort key for attention / lists: `urgencyRank DESC`, then `updated_at DESC`.  
Unknown urgency → rank 0 (sort last).

---

## 6. ProviderSnapshot (contract)

```lua
ProviderSnapshot = {
    schema_version = 1,

    -- Source identity (M1+; required for M6 without schema break)
    provider = "github",           -- "github" | "gitlab" | "gitea"
    host = "github.com",
    account = "alice",
    source_key = "github|github.com|alice",  -- canonical storage key

    state = "ready",               -- lifecycle state (see §7)
    data_state = "fresh",          -- "fresh" | "stale" | "empty"
    stale_since = nil,             -- unix sec when data became stale, if data_state=stale

    capabilities = { ... },        -- canonical keys only (§2)

    counts = {
        attention = 3,             -- distinct entity_id with attention=true
        reviews = 1,               -- signal counts (optional, for section badges)
        work_items = 2,
        issues = 0,
        ci = 1,
        notifications = 4,
    },

    items = { -- WorkItem signals
        {
            id = "github:notification:123",
            entity_id = "github:pr:github.com/org/repo#42",
            kind = "notification",
            title = "Review requested on feat/login",
            url = "https://github.com/org/repo/pull/42",
            repo = "org/repo",
            updated_at = 1727260000,
            urgency = "high",
            attention = true,
            read = false,
            provider = "github",
            host = "github.com",
            meta = {},
        },
    },

    activity = {},                 -- optional; only if capabilities.contributions

    fetched_at = 1727260000,       -- when this snapshot's data was obtained from CLI
    last_attempt_at = 1727260000,  -- last fetch attempt (success or fail)
    message = "",                  -- short human text (optional)

    error = nil,                   -- structured error when not ready (§8)
}
```

`source_key` format: `"{provider}|{host}|{account}"` (lowercase host). Empty account when `auth_required` / `unavailable`: use `"_"` placeholder, e.g. `github|github.com|_`.

### 6.1 Count semantics (M1)

- `counts.attention` is always **recomputed** by the domain from `items`
  (distinct `entity_id` where `attention == true`). A provider-supplied value that
  disagrees is a *warning* in validation and is never published (REQ-D-005).
- Other counters (`notifications`, `reviews`, `work_items`, `issues`, `ci`) are
  **signal counts over all items** of that kind, so section badges can show
  activity even when the signal is not part of the attention queue. A valid
  reported counter is trusted; an invalid one falls back to the derived count.
- `items` that fail the item contract (missing field, unknown kind/urgency, a
  non-`http(s)` URL) make the whole source **error-severity invalid**: the source
  is degraded to `bad_response` + `data_state = "empty"` and its items are not
  published. Recoverable sloppiness (aliasable capability keys, wrong counters,
  a newer `schema_version`) stays a `warn` and is repaired by normalization.


---

## 7. Lifecycle state vs data state (ADR-011)

**Do not use `state = "stale"`.** Staleness is orthogonal.

| `state` | Meaning |
|---------|---------|
| `ready` | Last attempt succeeded |
| `auth_required` | Not authenticated |
| `rate_limited` | Rate limit hit |
| `network_error` | Transport failure |
| `api_error` | Non-auth API / CLI failure |
| `bad_response` | Unparseable / schema mismatch |
| `loading` | In-flight (service synthetic) |
| `unavailable` | Provider disabled or CLI missing |

| `data_state` | Meaning |
|--------------|---------|
| `fresh` | Items reflect last successful fetch |
| `stale` | Showing last-good after a failed attempt |
| `empty` | No privileged items (cleared or never had) |

Examples:

- Success: `state=ready`, `data_state=fresh`
- Rate limit with last-good: `state=rate_limited`, `data_state=stale`, `stale_since=…`
- Auth loss: `state=auth_required`, `data_state=empty`, privileged items cleared, persisted snapshot invalidated (ADR-012)

---

## 8. Structured error object

When `state` ≠ `ready` and ≠ `loading`:

```lua
error = {
    code = "rate_limited",     -- machine-readable; usually mirrors state
    message = "API rate limit exceeded",
    retryable = true,
    retry_after = 120,         -- seconds, optional
    exit_code = 1,             -- CLI exit if applicable
}
```

UI MUST prefer `error.code` / `state` over parsing `message`.

---

## 9. Timestamps

| Field | Meaning |
|-------|---------|
| `fetched_at` | Time data was successfully obtained (frozen on last-good) |
| `last_attempt_at` | Time of last fetch attempt |
| `published_at` | Time Aggregator published the overview (overview only) |
| `stale_since` | When data_state became stale |

---

## 10. Aggregated overview (published to state)

**Shape is multi-host ready from M1** (ADR-014):

```json
{
  "schema_version": 1,
  "published_at": 1727260000,
  "refresh_id": 42,
  "mode": "all",
  "counts": {
    "attention": 5,
    "reviews": 2,
    "work_items": 3,
    "issues": 1,
    "ci": 1
  },
  "sources": [
    {
      "provider": "github",
      "host": "github.com",
      "account": "alice",
      "source_key": "github|github.com|alice",
      "snapshot": { }
    }
  ],
  "attention": [
    {
      "entity_id": "github:pr:github.com/org/repo#42",
      "urgency": "high",
      "title": "feat/login",
      "url": "https://github.com/org/repo/pull/42",
      "repo": "org/repo",
      "updated_at": 1727260000,
      "provider": "github",
      "host": "github.com",
      "signal_ids": ["github:notification:abc", "github:review:def"]
    }
  ],
  "capabilities_union": {
    "notifications": true,
    "reviews": true,
    "work_items": true,
    "issues": true,
    "ci": true,
    "contributions": true,
    "mark_read": true
  }
}
```

- UI groups `sources` by `provider` for tabs.
- Single-host GitHub-only: one element in `sources`.
- **Deprecated:** map key `"providers": { "github": … }` — do not use; breaks multi-host.

State key on `noctalia.state`: `dashboard`.

---

## 11. Persistence (ADR-012)

### Location

- Runtime data only under persistent plugin data directory (target API: confirm `noctalia.pluginDataDir()` vs documented equivalent on pinned Noctalia — see VERSION-MAP open gate).
- **Not** for user Settings — those are host-managed via `plugin.toml` `[[setting]]` + Noctalia config APIs (`getConfig` / equivalent).

### Files (suggested)

| File | Content |
|------|---------|
| `last-good.json` | Map `source_key` → ProviderSnapshot (privileged data) |
| `dedup.json` | Toast dedup timestamps by item `id` |
| `snooze.json` | Local snooze until (optional, M3+) |

### Auth invalidation

On `auth_required` for a source_key:

1. Clear in-memory privileged items for that source.
2. Delete or mark invalid the matching entry in `last-good.json`.
3. Publish overview with `state=auth_required`, `data_state=empty`.
4. **Do not** restore that last-good until a successful authenticated fetch.

On account/host switch: treat as different `source_key`; do not leak previous account’s private titles into the new identity.

### Retention (minimum)

| Policy | Default |
|--------|---------|
| `last_good_max_age_sec` | 86400 (24h) — older entries discarded on load |
| `max_items_per_kind` | 100 |
| `clear_on_auth_loss` | true (required) |

---

## 12. Empty vs unavailable vs zero items

| Situation | UI |
|-----------|-----|
| capability = false | Hide section or show “Not available on this provider” |
| capability = true, state ready, items = [] | “You’re clear” empty state |
| capability = true, state rate_limited/network, data_state=stale | Show last-good + banner |
| state = unavailable (CLI missing / disabled) | Provider-level banner; no fake sections |

---

## 13. URL validation

Open-URL path MUST allow only `http` and `https` schemes. Reject `file:`, `javascript:`, and any other scheme.
