# 00 — Executive Summary

## 1. Problem

Need a **unified Git work dashboard** in Noctalia 5 bar/panel:

- GitHub, GitLab, Gitea in one place
- Needs-attention / review queues
- Own PRs / MRs, assigned issues
- Provider-specific extras (Actions, pipelines) when available
- Contribution / activity graph
- Mark-as-read (where supported)
- Multi-host ready (Enterprise / self-hosted) as a later slice
- Keyboard-first triage
- **System notifications** for high-urgency events (outside panel)

Auth must reuse **existing CLI sessions** (`gh`, `glab`, `tea`) — no second token store.

## 2. Product positioning

> **One small, always-available developer inbox for all Git work.**

Mode `All` is the primary surface; provider tabs are drill-down.

**Canonical id:** `code-warlord-dev/git-dashboard`  
**Repo:** https://github.com/code-warlord-dev/git-dashboard

## 3. Delivery

| Phase | Outcome |
|-------|---------|
| M0 | Full docs + AGENTS + skills (this package) |
| M1 | Domain core + tests |
| M2 | Loadable plugin + GitHub + system notifications |
| M3 | GitHub polish (mark-read, Actions, keyboard, settings) |
| M4 | GitLab |
| M5 | Gitea |
| M6 | Multi-host + 1.0 stable contracts |

## 4. Success criteria (P0 / M2)

1. Authenticated `gh` → real data in bar + panel.
2. `All | GitHub` tabs work.
3. Lists + open URL + explicit error states.
4. System toast for high-urgency new items (when enabled).
5. No tokens stored by plugin.
6. Architecture accepts more providers without UI rewrite.

## 5. Unique value (see FEATURES.md)

- Unified attention across forges
- Capability-honest multi-provider UI
- Disciplined system toasts with urgency gate
- Stale-but-honest banners
- Keyboard triage mode
- Review aging / “what needs me” filters (M3+)
