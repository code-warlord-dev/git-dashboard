---
name: provider-github
description: GitHubProvider via gh CLI — notifications, reviews, PRs, issues, Actions, mark-read, urgency mapping, error classification. Use when implementing or debugging GitHub slice.
---

# Skill: provider-github

## Non-negotiables

1. Backend is `gh` only — no plugin PAT store.
2. Classify errors: auth vs rate_limited vs network vs api vs bad_response.
3. Set capabilities to match what you actually populate.
4. Urgency mapping per `docs/providers/github.md`.
5. Redact tokens from any logged collector output.

## Key paths

- `docs/providers/github.md`
- `docs/SPEC.md` REQ-G-*
- `docs/DATA-MODEL.md`
- `docs/NOTIFICATIONS.md` (urgency consumption)

## Preferred subagent

Jordan (Provider Specialist — GitHub)

## Done-when

- [ ] T-G-* for touched behavior
- [ ] Live `gh auth status` path tested on at least one machine
- [ ] Mark-read does not require full restart
- [ ] Actions respect action_scan_behavior
