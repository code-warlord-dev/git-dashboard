# Provider: GitHub (P0 / M2–M3)

**Backend:** `gh` CLI  
**Host default:** `github.com` (Enterprise in M6)  
**Capability set (canonical):** notifications, reviews, work_items, issues, ci, contributions, mark_read  

---

## 1. Identity

| Field | Source |
|-------|--------|
| account | `gh api user --jq .login` or `gh auth status` |
| host | parsed from `GH_HOST` / `gh` config / default github.com |

Unauthenticated → `state = auth_required`, empty items, capabilities may still be declared as “supported when auth”.

---

## 2. Data sources (recommended CLI paths)

Prefer stable `gh` commands and `gh api` with explicit paths. Avoid HTML scrape except for contributions behind a feature flag.

| Data | Suggested command / approach |
|------|------------------------------|
| Notifications | `gh api` notifications endpoint (exact path/fields in collector freeze); **not** `gh notify` (not a core CLI command). Optionally consider `gh status` only as discovery/high-level attention, not as sole source — final strategy C preferred: API notifications + gh pr/issue/run (freeze before M2) |
| Review requests | search / `gh api` search issues + pulls with review-requested |
| Open PRs (author / assignee) | `gh pr list --author @me` / `--assignee @me` |
| Issues | `gh issue list --assignee @me` |
| CI runs | `gh run list` limited by `action_scan_behavior` (`off` \| `recent`; `watched` deferred until model exists) |
| Mark read | `gh api -X PATCH /notifications/threads/{id}` or batch |
| Contributions | GraphQL contribution calendar when possible; else degrade |

Exact argv arrays live in `providers/github.luau` / `bin/github-fetch` and must be testable offline with fixtures.

---

## 3. Urgency mapping (GitHub → urgency)

| GitHub event | urgency |
|--------------|---------|
| Review requested on your PR or you are requested | high (critical if on protected/default branch and setting allows) |
| Mention in issue/PR | high or normal (setting) |
| Assignment | high |
| CI failure on default branch of a watched repo | high |
| CI failure on your PR | high |
| CI success | low |
| Subscribed issue comment (no mention) | normal / low |
| Bot-only noise | low |

Provider sets `item.urgency`; Notifications module only filters.

---

## 4. UI/UX — GitHub tab & sections

### 4.1 Widget

- Glyph: forge icon or generic git icon; color/urgent when `counts.attention > 0`.
- Badge: numeric attention or dot.
- Tooltip: “GitHub · 3 need attention · @login”.

### 4.2 Panel — All | GitHub

**GitHub tab layout (top → bottom):**

1. Header: account @ host · last fetch age · state banner if not ready
2. Section: **Needs attention** (merged high-urgency items)
3. Section: **Reviews** (pending review requests)
4. Section: **Pull requests**
5. Section: **Issues**
6. Section: **CI / Actions** (if capabilities.ci + setting)
7. Section: **Activity / contributions** (if capabilities.contributions + setting)

Empty section with capability true → “You’re clear” empty state.  
Capability false → section omitted.

### 4.3 Item row

```text
[urgency chip] title                          repo · 2h ago
               subtitle / actors              [Mark read] [Open]
```

Keyboard: focus row → Enter open, `m` mark read, `o` open browser.

### 4.4 Error banners

| State | Banner copy (example) |
|-------|------------------------|
| auth_required | Sign in with `gh auth login` |
| rate_limited | Rate limited · showing data from N min ago |
| network_error | Network error · showing last-good |
| api_error | GitHub API error · message |

### 4.5 Mark-read UX (M3)

- Single: key or button → optimistic remove/fade → API → reconcile
- Mark all: confirmation or “Mark all visible” with undo window if feasible
- Failure: restore item + toast error

---

## 5. Settings that affect GitHub

| Setting | Effect on GitHub |
|---------|------------------|
| `enabled_providers` includes `"github"` | Provider runs |
| `action_scan_behavior` | off / recent (`watched` deferred) |
| `include_contributions` | Activity section |
| `notifications.*` | Toasts for high-urgency GitHub items |
| `poll_interval_sec` | Refresh cadence |

---

## 6. Failure isolation

GitHub failure MUST leave Aggregator able to show other providers (when present).  
GitHub-only install: panel shows GitHub error states clearly; widget reflects auth/rate/network.

---

## 7. Tests (GitHub-specific)

| ID | Case |
|----|------|
| T-G-001 | Unauthenticated gh → auth_required |
| T-G-002 | Rate limit response → rate_limited + last-good |
| T-G-003 | Mark single notification read |
| T-G-004 | Open URL uses argv xdg-open |
| T-G-005 | CI section hidden when capability false or setting off |
| T-G-006 | Contributions degrade without crash |

---

## 8. Implementation notes for Jordan (subagent)

1. Load skills: `provider-github`, `implement`, `git-dashboard`.
2. Prefer fixture-based unit tests for parser before live `gh` calls.
3. Never log raw `gh` output that may contain tokens.
4. Classify errors with the taxonomy in DATA-MODEL.md — do not invent new states.
5. Capability flags must match what the current code path actually fills.


---

## 9. Collector freeze (before M2.3)

For each collector, document before coding:

| Field | Required |
|-------|----------|
| Purpose | |
| Exact argv (with LANG=C) | |
| Expected JSON fields | |
| Exit-code → state mapping | |
| Rate-limit detection | |
| Auth detection | |
| Timeout | |
| Max items | |
| Fixture path | |

Minimum for M2: identity, notifications, reviews, work_items (`kind=pull_request`), issues.  
mark_read + ci_run: M3.


---

## 10. Notification / attention source strategy (freeze before M2)

**Forbidden:** `gh notify` (not a GitHub CLI core command).

**Preferred (hybrid C):**
1. Identity: `gh api user` / `gh auth status`
2. Notifications: `gh api` notifications endpoint with explicit fields + pagination
3. Reviews / work_items / issues: `gh pr list`, `gh issue list` (and review-requested search as needed)
4. CI (M3): `gh run list` with `action_scan_behavior` = `off` | `recent` only

`gh status` may be used for discovery or smoke, not as the sole normative data source for entity/signal model.

Final argv + JSON projection live in the collector freeze table (§9) — fill before M2.3.
