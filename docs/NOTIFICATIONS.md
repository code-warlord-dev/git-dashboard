# NOTIFICATIONS.md — System Toasts & Urgency Model

**Plugin:** `code-warlord-dev/git-dashboard`  
**Scope:** Notifications **outside** the panel UI — desktop toasts via Noctalia  
**Last updated:** 2026-09-26

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
| `notifications.dedup_minutes` | int | `30` | Same item id suppressed within window |
| `notifications.quiet_hours` | object \| null | `null` | `{ start = "22:00", end = "08:00" }` local time |
| `notifications.include_actions` | bool | `true` | Whether Actions/pipeline failures can toast |
| `notifications.sound` | bool | shell default | Prefer shell DND / sound settings; do not force |

Quiet hours suppress **toasts only**. Panel, badge, and state continue to update.

---

## 5. Evaluation algorithm (service)

```text
On new overview after refresh:
  prev = last published overview (in memory)
  for each item in overview.attention (or new items set):
    if item.urgency < settings.min_urgency: skip
    if not settings.enabled: skip
    if in quiet hours: skip
    if item.id seen in dedup window: skip
    if item was already present in prev with same read state: skip
    emit toast(title, body)
    record item.id in dedup map with timestamp
```

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

## 10. Testing (T-N-*)

| ID | Case |
|----|------|
| T-N-001 | high urgency new item → toast when enabled |
| T-N-002 | same item within dedup window → no second toast |
| T-N-003 | min_urgency = critical → high item silent |
| T-N-004 | quiet hours → no toast, badge still updates |
| T-N-005 | enabled = false → silence |
| T-N-006 | cold start with many unread → no toast storm |

---

## 11. Future (post-1.0)

- Per-repo urgency overrides
- Digest mode (“3 new reviews”) instead of one toast per item
- Integration with shell notification history if API allows persistent plugin notifications
