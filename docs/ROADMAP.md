# ROADMAP — Git Dashboard

**Canonical id:** `code-warlord-dev/git-dashboard`  
**Delivery model:** Vertical slices on multi-provider architecture  
**Last updated:** 2026-09-26 (ADR-016…018)

---

## 1. Principles

1. Multi-provider is architecture from day one; providers ship as vertical slices.
2. Ship usable Core + GitHub before GitLab / Gitea.
3. Every milestone has exit criteria tied to SPEC REQ-* and T-*.
4. One milestone **in progress** at a time unless human parallelizes.
5. Completing a milestone requires its exit criteria + `PROGRESS.md` checkboxes + ROADMAP phase status + CHANGELOG bullet (AGENTS.md §13.1).

**Progress markers (AGENTS.md §13.1)** — phase tables, the milestone overview and exit
criteria carry a status. Updated only when work lands on `main`.

| Marker | Meaning |
|--------|---------|
| ✅ done | Merged to `main` and verified (tests / CI) |
| 🟡 in progress | Branch or PR open, not merged |
| ⬜ planned | Not started |

---

## 2. Milestone overview

| Milestone | Name | Focus | Target version | Status |
|-----------|------|-------|----------------|--------|
| **M0** | Foundations | Docs, AGENTS, skills, SPEC skeleton, ADRs | 0.0.0 | ✅ done (PR #1) |
| **M0.5** | Contract hardening | ADR-009…014, audit fixes, honest inventory, gates | 0.0.0 | ✅ done (PR #1) |
| **M1** | Domain Core | ProviderSnapshot, Aggregator, capabilities, error taxonomy, unit tests | 0.1.0 | ✅ done — released and tagged `v0.1.0` |
| **M2** | MVP Plugin + GitHub | service + widget + panel + GitHubProvider + system notifications | 0.2.0 | ⬜ planned (blocked on G-API-1…3 pin) |
| **M3** | GitHub polish + Settings | Mark-read, Actions, contributions, keyboard, settings schema | 0.3.0 | ⬜ planned |
| **M4** | GitLab | GitLabProvider, independent isolation, All | GitHub | GitLab tabs | 0.4.0 | ⬜ planned |
| **M5** | Gitea + Capability honesty | GiteaProvider, hide/unavailable sections | 0.5.0 | ⬜ planned |
| **M6** | Multi-host + Stable 1.0 | host → identity → capabilities, freeze contracts | 1.0.0 | ⬜ planned |


---

## 3. Detailed milestones → phases → stages

### M0 — Foundations (docs only) ✅ done — PR #1

**Goal:** Complete operating contract so any agent can start without re-deriving architecture.

**Phases**

| Phase | Stages | Deliverables |
|-------|--------|--------------|
| M0.1 Docs core | Architecture, Data Model, Components, SPEC skeleton, ROADMAP, VERSION-MAP | This package |
| M0.2 Agents | AGENTS.md, named subagents, skills inventory, SESSION/PROGRESS templates | AGENTS.md + `.agents/skills/` |
| M0.3 Decisions | Initial ADRs (multi-provider, CLI auth, capability model, notifications) | docs/DECISIONS.md |
| M0.4 Unique features | Brainstorm + prioritization | docs/FEATURES.md |

**Exit criteria**

- [x] All docs listed in package README exist and are cross-linked *(PR #1)*
- [x] AGENTS.md activation matrix covers P0–P3 tasks *(PR #1)*
- [x] At least 5 project skills have valid SKILL.md *(PR #1)*
- [x] PROGRESS.md M0 checkboxes can be marked *(PR #1)*

---

### M1 — Domain Core (no UI yet) ✅ done — PR #2 + PR #3

**Goal:** Pure domain layer that can be unit-tested without Noctalia or network.

**Phases**

| Phase | Stages | SPEC focus | Status |
|-------|--------|------------|--------|
| M1.1 Schema | ProviderSnapshot schema v1, capability flags, error taxonomy | REQ-D-001 … REQ-D-010 | ✅ done — PR #2 |
| M1.2 Aggregator | DashboardAggregator: merge, filter, counts, isolation | REQ-A-001 … REQ-A-008 | ✅ done — PR #2 |
| M1.3 Tests | T-D-* and T-A-* unit tests (fixtures, no CLI) | T-D-001 … T-A-007 | ✅ done — 42 cases across PR #2 + PR #3 |
| M1.4 Stale policy | Last-good window, banner rules, refresh generation | REQ-A-009, REQ-S-005 | ✅ done — PR #3 |

**Exit criteria**

- [x] Aggregator accepts 0..N ProviderSnapshots and produces unified overview *(T-A-001, PR #2)*
- [x] Capability hide rules unit-tested *(T-A-004, PR #2)*
- [x] Error isolation unit-tested (one bad provider does not poison All) *(T-A-002, PR #2)*
- [x] Schema version field present *(T-D-001, PR #2)*
- [x] Domain free of Noctalia and forge-specific types *(lib/ requires only siblings, PR #2)*

**Milestone closed:** M1.1–M1.4 merged, released in PR #4, and tagged `v0.1.0`. All exit criteria satisfied and proven by 42 unit tests.

**Version:** 0.1.0 (domain lib / tests)

---

### M2 — MVP Plugin + GitHub (P0)

**Goal:** Loadable Noctalia plugin with real GitHub data and system notifications.

**Phases**

| Phase | Stages | SPEC focus |
|-------|--------|------------|
| M2.1 Scaffold | plugin.toml (id, plugin_api per pin / ≥24 when argv required), service/widget/panel stubs, lib layout | REQ-P-001 |
| M2.2 Service orchestration (per-source refresh ADR-017) | Poll timer, runAsync argv collectors, publish to noctalia.state | REQ-S-001 … REQ-S-006 |
| M2.3 GitHubProvider | Identity, notifications, reviews, PRs, issues via `gh` | REQ-G-001 … REQ-G-012 |
| M2.4 Widget | Badge (urgent + counts), click → togglePanel | REQ-W-001 … REQ-W-004 |
| M2.5 Panel shell | All \| GitHub tabs, lists, open URL, explicit error banners | REQ-U-001 … REQ-U-010 |
| M2.6 System notifications | Urgency model, noctalia.notify(title,body), **M2 settings subset**, rate-limit awareness | REQ-N-001 … REQ-N-008, REQ-C-009 … REQ-C-014 |
| M2.7 Cold start | Last-good from pluginDataDir | REQ-S-007 |

**Exit criteria**

- [ ] Authenticated machine shows real GitHub data
- [ ] All tab works with single provider
- [ ] Auth vs rate-limit vs network errors are distinct
- [ ] System toast fires for high-urgency new items (when enabled)
- [ ] Architecture already accepts additional providers without UI rewrite
- [ ] No tokens stored by plugin

**Version:** 0.2.0

---

### M3 — GitHub polish + Settings

**Goal:** Production-quality GitHub experience + configurable behavior.

**Phases**

| Phase | Stages | SPEC focus |
|-------|--------|------------|
| M3.1 Mark-read | Single + mark-all; optimistic UI; re-sync | REQ-G-013 … REQ-G-016 |
| M3.2 Actions | Recent workflow runs, open URL, cost control setting | REQ-G-017 … REQ-G-020 |
| M3.3 Contributions | Activity / contribution graph (feature-flagged) | REQ-G-021 … REQ-G-023 |
| M3.4 Keyboard | Full keyboard + auth recovery hotkey `a` + focus restore | REQ-U-011 … REQ-U-015, REQ-U-018, REQ-U-019 |
| M3.4b Digest toasts | F-B1 digest when burst of high/critical | REQ-N-009, REQ-C-016 |
| M3.5 Settings schema | enabled_providers, intervals, notification prefs, action_scan | REQ-C-001 … REQ-C-008 |
| M3.6 i18n + lint | translations/en.json, noctalia plugins lint clean | — |

**Exit criteria**

- [ ] Mark-read updates GitHub and local list without full restart
- [ ] Actions section respects capability + cost setting
- [ ] Keyboard can triage without mouse
- [ ] All settings documented in USER.md

**Version:** 0.3.0

---

### M4 — GitLab (P1)

**Goal:** Second provider with full isolation.

**Phases**

| Phase | Stages | SPEC focus |
|-------|--------|------------|
| M4.1 GitLabProvider | glab-backed: MRs, reviews, issues, pipelines as available | REQ-L-001 … REQ-L-010 |
| M4.2 Tabs | All \| GitHub \| GitLab; aggregated attention | REQ-U-016 |
| M4.3 Isolation verification | Auth failure on GitLab does not affect GitHub | REQ-A-010 |
| M4.4 Capability honesty | No fake Actions section for GitLab | REQ-A-011 |

**Exit criteria**

- [ ] GitLab auth failure does not affect GitHub lists
- [ ] Aggregated attention queue mixes both providers correctly
- [ ] Capability table hides unavailable sections

**Version:** 0.4.0

---

### M5 — Gitea + Capability honesty (P2)

**Goal:** Third provider; dashboard usable with any subset of providers.

**Phases**

| Phase | Stages | SPEC focus |
|-------|--------|------------|
| M5.1 GiteaProvider | tea-backed; honest limited capabilities | REQ-T-001 … REQ-T-008 |
| M5.2 Tabs + settings | Include Gitea; enabled_providers list | REQ-C-002 |
| M5.3 Degradation | Hide or mark unavailable; never empty fake sections | REQ-A-012 |

**Exit criteria**

- [ ] Dashboard usable with any subset of providers enabled
- [ ] Capability model drives UI completely

**Version:** 0.5.0

---

### M6 — Multi-host + Stable 1.0 (P3)

**Goal:** Host → identity → capabilities → snapshot; freeze user contracts.

**Phases**

| Phase | Stages | SPEC focus |
|-------|--------|------------|
| M6.1 Host model | provider → host → identity | REQ-H-001 … REQ-H-006 |
| M6.2 UI host switch | `[` / `]` when multiple hosts present | REQ-U-017 |
| M6.3 Enterprise / self-hosted | GitHub Enterprise, self-managed GitLab, self-hosted Gitea | REQ-H-007 |
| M6.4 Contract freeze | Dispatcher/settings/notification urgency stable | — |
| M6.5 Release 1.0 | CHANGELOG, VERSION-MAP, nested smoke, tag | — |

**Exit criteria**

- [ ] Two hosts under one provider appear as separate identities with isolation
- [ ] USER.md / API.md match behavior
- [ ] 1.0 contracts declared stable

**Version:** 1.0.0

---

## 4. Work breakdown (P0 / M2 suggested order)

1. Fixture service + widget + empty panel with tabs shell
2. ProviderSnapshot schema + aggregator unit tests (from M1)
3. GitHubProvider + collector integration
4. Notifications list + open URL
5. Reviews / PRs / issues
6. System notifications (Riley)
7. Mark paths (can slip to M3 if needed)
8. Keyboard foundation
9. Error isolation polish + stale policy
10. README / lint / thumbnail

---

## 5. Definition of Done (per PR)

- [ ] No invented Runtime API calls
- [ ] `plugin_api` matches used features
- [ ] Errors visible and correctly classified
- [ ] No token in logs or state
- [ ] UI does not branch on provider string outside capability checks
- [ ] README / IPC surface updated if needed
- [ ] SPEC IDs listed in PR body
- [ ] Tests for touched T-IDs

---

## 6. Feature flags / settings (early)

| Flag | Default | Effect |
|------|---------|--------|
| `enabled_providers` | `["github"]` | Which providers run |
| `poll_interval_sec` | 120 | Service refresh |
| `include_contributions` | true | Calendar / activity |
| `action_scan_behavior` | recent | GitHub Actions cost control |
| `notifications.enabled` | true | System toasts |
| `notifications.min_urgency` | high | Which events produce toasts |
| `notifications.quiet_hours` | null | Optional quiet window |

---

## 7. Open items before coding

### Before M1.3
1. ~~Choose Luau unit-test runner~~ → **ADR-015 Accepted** (minimal in-repo pure Luau harness).

### Before M2 scaffold
1. **Pin Noctalia** tag/commit + record argv `plugin_api` level (ADR-006 → Accepted).
2. Confirm persistent data dir API name on that pin.
3. Confirm `onConfigChanged` for interval / enabled_providers.
4. Capture real stdout of `gh` collectors for schema/fixtures (LANG=C).
5. Freeze argv contracts for: identity, notifications, reviews, work_items, issues (mark_read, ci → M3).
6. `action_scan_behavior=watched` requires a watched-repo model — **defer watched** until defined; M2/M3 use `off | recent` only unless model is added.
7. Plugin id fixed: `code-warlord-dev/git-dashboard`.

### M2 settings subset (ship with M2, not only M3)
- `enabled_providers` (default `["github"]`)
- `poll_interval_sec`
- `notifications.enabled`
- `notifications.min_urgency`
- `notifications.dedup_minutes`
- `notifications.quiet_hours`
- `notifications.include_actions`
