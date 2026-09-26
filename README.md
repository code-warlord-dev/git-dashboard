# Git Dashboard for Noctalia — Full Documentation Package

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
| plugin_api | Pin on target Noctalia (argv form per ADR-006 — Proposed until pin) |
| Compositor | None (Niri keybind is user config only) |

---

## Success criteria (P0 / Core + GitHub)

1. Authenticated `gh` → real data in bar + panel.
2. `All | GitHub` tabs; All aggregates correctly with one provider.
3. Notifications / reviews / PRs / issues with open-URL.
4. Mark-read works without full restart.
5. Explicit states: `ready`, `auth_required`, `rate_limited`, `network_error`, `stale`.
6. No tokens stored by the plugin.
7. Architecture already accepts additional providers without UI rewrite.
8. System notifications fire for high-urgency items (configurable).

---

## License note

Architecture & documentation package. Implementation code lives in the main repository.  
Upstream Omarchy plugins are MIT; this package is documentation only.
