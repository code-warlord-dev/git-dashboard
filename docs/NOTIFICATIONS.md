# NOTIFICATIONS.md — System Toasts & Urgency Model

**Plugin:** `code-warlord-dev/git-dashboard`  
**Scope:** Notifications **outside** the panel UI — desktop toasts via Noctalia  
**Last updated:** 2026-09-26 (ADR-016 urgency-aware dedup)

---

## 1. Why system notifications

The panel is the triage surface. System toasts exist so the user learns about **high-value events** without opening the panel:

- New review request on a critical PR
- CI failure on a watched branch
- Mention / assignment that requires immediate attention

Toasts must be **opt-in by urgency**, deduplicated, and quiet-hours aware. Spam kills the feature.

---

## 2. Channel

Primary channel: **`noctalia.notify(title, body)`** (documented Runtime API). Optional: `noctalia.notifyError(title, body)` if present.

- **No third `opts` argument** — urgency, dedup, quiet hours, and click intent are plugin policy only.
- Toast click / actions (REQ-N-008) are **MAY** only if a future/pinned Runtime API exposes them; until then toasts are informational.
- Prefer the Noctalia Runtime API over raw `notify-send` so theming, DND, and position respect shell settings.
- Fallback: if Runtime API lacks notify, document the limitation and degrade to panel-only (badge still updates).

**Never** invent a second notification daemon.

---

## 3. Urgency model

Every normalized item carries an `urgency` field:

| Level | Meaning | Typical sources | Default toast? |
|-------|---------|-----------------|----------------|
| `critical` | Needs action now | Review request on your PR, security alert, force-push to protected branch (if detectable) | Yes |
| `high` | Important, same day | New review request, CI failed on main/master, assignment to issue you own | Yes (if min_urgency ≤ high) |
| `normal` | Useful, not urgent | Comment on watched issue, PR merged, pipeline succeeded | No (unless min_urgency = normal) |
| `low` | Informational | Bot noise, closed issues, routine workflow runs | No |

Mapping from forge events → urgency is **provider responsibility** (see provider docs). Aggregator and Notifications module only consume the field.

---

## 4. Settings (REQ-C / REQ-N)

| Key | Type | Default | Effect |
|-----|------|---------|--------|
| `notifications.enabled` | bool | `true` | Master switch for plugin toasts |
| `notifications.min_urgency` | enum | `high` | `critical` \| `high` \| `normal` \| `low` |
| `notifications.dedup_minutes` | int | `30` | Base window for normal/low (signal `id`) |
| `notifications.dedup_minutes_high` | int | `15` | Effective window for urgency=high (ADR-016) |
| `notifications.dedup_minutes_critical` | int | `5` | Effective window for urgency=critical (ADR-016) |
| `notifications.digest_enabled` | bool | `true` | Prefer digest toast on burst (F-B1 / ADR-016) |
| `notifications.digest_window_minutes` | int | `10` | Burst window for digest aggregation |
| `notifications.quiet_hours` | object \| null | `null` | `{ start = "22:00", end = "08:00" }` local time |
| `notifications.include_actions` | bool | `true` | Whether Actions/pipeline failures can toast |
| `notifications.sound` | bool | shell default | Prefer shell DND / sound settings; do not force |

Quiet hours suppress **toasts only**. Panel, badge, and state continue to update.

---

## 5. Evaluation algorithm (service)

```text
On new overview after refresh:
  prev = last published overview (in memory)
  candidates = []
  for each signal/item that is toast-worthy:
    if item.urgency < settings.min_urgency: skip
    if not settings.enabled: skip
    if in quiet hours: skip
    window = effective_dedup_window(item.urgency)   # ADR-016
    if item.id seen in dedup map within window: skip
    if item was already present in prev with same read state: skip
    candidates.append(item)

  if digest_enabled and burst of ≥2 high/critical with same entity_id or (kind, repo):
    emit one digest toast
    record all candidate ids in dedup map
  else:
    for item in candidates:
      emit toast(title, body)
      record item.id in dedup map with timestamp

effective_dedup_window(urgency):
  critical → dedup_minutes_critical (default 5)
  high     → dedup_minutes_high (default 15)
  normal|low → dedup_minutes (default 30)
```

**Rationale (expert review):** a second CI failure minutes after a failed fix must not be silent when urgency is high/critical; routine noise still uses the longer window.

Title examples:
- `"Review requested · org/repo#42"`
- `"CI failed · org/repo · main"`
- `"Assigned · org/repo#17"`

Body: short, no tokens, no diffs. Prefer repo + title + actor when available.

---

## 6. Click / action behavior

**MAY** when Runtime API supports notification actions (not required for M2):

1. Default action: open the panel (`togglePanel`) or item URL.
2. Secondary: “Mark read” if mark_read capability exists.

If actions are unsupported (current documented API), toast is informational only; user opens panel via widget or keybind.

---

## 7. Types of events that MAY produce toasts

| Event kind | Default urgency | Notes |
|------------|-----------------|-------|
| Review request (you) | high / critical | Highest value |
| CI / Actions failure on default branch | high | If `include_actions` |
| Issue / PR assignment to you | high | |
| Mention in comment | normal → high (configurable later) | |
| PR merged (yours) | normal | |
| Pipeline success | low | Usually silent |
| Rate-limit approaching | normal | Banner in panel preferred; optional toast once |
| Auth lost | high | One toast, then panel banner |

Providers MUST NOT invent toast-worthy events that the capability model does not support.

---

## 8. What must never toast

- Every single notification from the forge inbox (too noisy)
- Bot-only noise without user involvement
- Events already marked read
- Events older than the current poll window on first start (avoid toast storm on cold start)
- Any payload containing credentials or private key material

---

## 9. Interaction with FreeDesktop / shell DND

- Respect Noctalia DND and notification filters.
- Plugin toasts should identify as the plugin (app name / desktop-entry style) so users can filter them in shell settings if desired.
- Do not bypass DND.

---

## 10. Digest toasts (F-B1 / ADR-016)

When multiple high/critical events would toast in one evaluation pass (or within `digest_window_minutes`), prefer a single summary:

- Example title: `"3 CI failures · org/repo"`
- Example body: `"Last 10 minutes · open panel for details"`

Digest does not replace panel state. Target: M3 (may land earlier). M2 may ship without digest if urgency-aware windows alone are implemented.

---

## 11. Testing (T-N-*)

| ID | Case |
|----|------|
| T-N-001 | high urgency new item → toast when enabled |
| T-N-002 | same item within dedup window → no second toast |
| T-N-003 | min_urgency = critical → high item silent |
| T-N-004 | quiet hours → no toast, badge still updates |
| T-N-005 | enabled = false → silence |
| T-N-006 | cold start with many unread → no toast storm |
| T-N-007 | critical repeat after 6 min (>5) → toast again |
| T-N-008 | high repeat after 10 min (<15) → suppressed |
| T-N-009 | digest collapses ≥2 critical same entity in one pass |

---

## 11. Future (post-1.0)

- Per-repo urgency overrides
- Digest mode (“3 new reviews”) instead of one toast per item
- Integration with shell notification history if API allows persistent plugin notifications
