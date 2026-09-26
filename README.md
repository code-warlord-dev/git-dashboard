# Git Dashboard for Noctalia

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI — domain tests](https://github.com/code-warlord-dev/git-dashboard/actions/workflows/domain-tests.yml/badge.svg)](https://github.com/code-warlord-dev/git-dashboard/actions/workflows/domain-tests.yml)
[![Lua / Luau](https://img.shields.io/badge/Lua-5.4%20%7C%20Luau-2C2D72?logo=lua&logoColor=white)](scripts/run-domain-tests.sh)
[![Milestone](https://img.shields.io/badge/M1-domain%20core-brightgreen)](docs/ROADMAP.md)
[![Schema](https://img.shields.io/badge/ProviderSnapshot-v1-blue)](docs/DATA-MODEL.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](https://github.com/code-warlord-dev/git-dashboard/pulls)
[![Topics](https://img.shields.io/badge/topics-noctalia%20%7C%20luau%20%7C%20dashboard-informational)](https://github.com/code-warlord-dev/git-dashboard)

**Canonical plugin id:** `code-warlord-dev/git-dashboard`  
**Repository:** https://github.com/code-warlord-dev/git-dashboard  
**Target:** Noctalia Shell 5.x (Luau plugins)  
**Primary host:** Niri (compositor-agnostic by design)  
**Providers (architecture day-one):** GitHub → GitLab → Gitea → Multi-host  
**Document status:** M0.5 contract-hardened foundation (architecture + agents + specs + roadmap). Skills inventory is partial by design — expand on demand.  
**Date:** 2026-09-26  

---

## What this package is

This is the **full operating contract** for the project:

- Architecture, data model, component boundaries
- Roadmap broken into milestones → phases → stages with detailed SPECs
- Version map + changelog rules
- AGENTS.md (orchestrator + named subagents)
- Project skills under `.agents/skills/`
- Agent-state files (SESSION / PROGRESS)
- Provider-specific models & UI/UX (GitHub first, detailed)
- System notifications design (outside panel UI)
- Unique features brainstorm (beyond reference plugins)
- Security, resilience, ADRs

**Delivery order (non-negotiable):**  
`P0 Core + GitHub` → `P1 GitLab` → `P2 Gitea` → `P3 Multi-host`

Multi-provider is **architecture from commit 1**. Implementation is vertical slices.

---

## Package layout

```text
git-dashboard-full-docs/
├── README.md                          ← you are here
├── AGENTS.md                          ← orchestrator contract + named subagents
├── docs/
│   ├── 00-executive-summary.md
│   ├── ARCHITECTURE.md
│   ├── DATA-MODEL.md
│   ├── COMPONENTS.md
│   ├── SPEC.md                        ← normative requirements (REQ-*)
│   ├── ROADMAP.md                     ← milestones M0–M6 + phases
│   ├── VERSION-MAP.md
│   ├── DECISIONS.md                   ← ADRs
│   ├── NOTIFICATIONS.md               ← system toasts + urgency model
│   ├── FEATURES.md                    ← unique features beyond references
│   ├── SECURITY.md
│   ├── USER.md                        ← user-facing contracts
│   ├── API.md                         ← Noctalia Runtime API usage
│   ├── providers/
│   │   ├── github.md                  ← detailed models + UI/UX (P0)
│   │   ├── gitlab.md
│   │   └── gitea.md
│   ├── agent-state/
│   │   ├── SESSION.md
│   │   └── PROGRESS.md
│   └── adr/                           ← individual ADR files if needed
├── .agents/skills/                    ← project skills (SKILL.md where present)
│   ├── git-dashboard/          ✓
│   ├── noctalia-plugin/        ✓
│   ├── provider-github/        ✓
│   ├── notifications/          ✓
│   ├── plugin-spec-compliance/ ✓
│   ├── implement/              (stub dir — fill on demand)
│   ├── research/               (stub dir — fill on demand)
│   └── writing-plans/          (stub dir — fill on demand)
│   # provider-gitlab, provider-gitea, to-spec, to-tickets,
│   # code-review, diagnosing-bugs, find-skills: planned, not shipped yet
└── diagrams/
    ├── component.mmd
    ├── data-flow.mmd
    └── lifecycle.mmd
```

---

## Implementation (repository root)

```text
lib/            domain core (M1): schema, aggregator, capabilities, errors, urgency
tests/          pure domain tests + fixtures (ADR-015 harness)
scripts/        run-domain-tests.sh — domain gate, local and CI
providers/      forge providers (M2 github, M4 gitlab, M5 gitea)
plugin.toml     + service.luau / widget.luau / panel.luau (M2)
.github/        PR template + domain-tests workflow
```

**Status:** the M1 domain core is implemented and covered by 29 cases
(`29 passed, 0 failed`). M2 (plugin scaffold + GitHubProvider) is gated on the
Noctalia pin (`docs/VERSION-MAP.md` G-API-1…3).

**Run the domain tests:**

```bash
scripts/run-domain-tests.sh              # picks luau, else lua5.4 / lua / luajit
LUA=luajit scripts/run-domain-tests.sh   # explicit interpreter
```

---

## Quick start for agents

1. Read `AGENTS.md` (role = Orchestrator).
2. Read `docs/agent-state/SESSION.md` + `PROGRESS.md`.
3. Read only the SPEC sections listed in `SPEC focus`.
4. Match task → activation matrix in AGENTS.md §3.5.
5. Delegate to named subagents with brief ≤40 lines.
6. Never invent Noctalia Runtime API calls — verify against docs.noctalia.dev.

---

## Key architectural decisions (summary)

| Decision | Choice |
|----------|--------|
| Product model | Multi-provider from architecture day one |
| Delivery | Vertical slices: Core+GitHub → GitLab → Gitea → Multi-host |
| Collectors | CLI-backed (`gh` / `glab` / `tea`) — no plugin token store |
| UI | Works only on normalized model + capabilities |
| Auth | Existing CLI sessions only |
| Notifications | System toasts via `noctalia.notify(title, body)` + plugin-side urgency model |
| Panel open | `noctalia.togglePanel("code-warlord-dev/git-dashboard:panel")` |
| plugin_api | Pin on target Noctalia (argv form per ADR-006 — Accepted with pin prerequisite) |
| Compositor | None (Niri keybind is user config only) |

---

## Success criteria (P0 / Core + GitHub)

1. Authenticated `gh` → real data in bar + panel.
2. `All | GitHub` tabs; All aggregates correctly with one provider.
3. Notifications / reviews / PRs / issues with open-URL.
4. Mark-read works without full restart.
5. Explicit lifecycle states: `ready`, `auth_required`, `rate_limited`, `network_error`, `api_error`, `bad_response`, `loading`, `unavailable` — with `data_state` (`fresh` | `stale` | `empty`) orthogonal to them (ADR-011).
6. No tokens stored by the plugin.
7. Architecture already accepts additional providers without UI rewrite.
8. System notifications fire for high-urgency items (configurable).

---

## License

MIT — see `LICENSE`. Documentation package plus Luau implementation in this
repository; upstream Omarchy plugins are MIT as well, this project contains no
copied QML/bash code.
