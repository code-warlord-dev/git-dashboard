---
name: notifications
description: System toasts for git-dashboard — urgency model, noctalia.notify, dedup, quiet hours, settings. Use when implementing or tuning notification policy outside the panel.
---

# Skill: notifications

## Non-negotiables

1. Follow `docs/NOTIFICATIONS.md` contract.
2. Never toast on cold start for pre-existing unread (no storm).
3. Dedup by item id within window.
4. Respect enabled, min_urgency, quiet_hours.
5. Toast body: no tokens, no diffs, no secrets.

## Preferred subagent

Riley (Notifications & System UX)

## Key paths

- `docs/NOTIFICATIONS.md`
- `docs/SPEC.md` REQ-N-*
- `docs/providers/github.md` (urgency mapping)

## Done-when

- [ ] T-N-* pass
- [ ] Settings schema includes notifications.* keys
- [ ] DND / shell filters still work
