# Progress
Updated: 2026-09-26 (after M1.1 + M1.2)

## M0 Foundations ✅
- [x] Core docs, AGENTS, skills inventory (honest), diagrams (notification-flow deferred)
- [x] Landed in repository `code-warlord-dev/git-dashboard` (public, MIT) through PR #1 → `main`

## M0.5 Contract hardening ✅
- [x] ADR-009…014 + ADR-015 (test runner)
- [x] Plugin id code-warlord-dev/git-dashboard
- [x] notify(title, body); settings vs data dir
- [x] TRACEABILITY living matrix
- [x] Remove gh notify; canonical capabilities in gitlab/gitea docs
- [x] REQ-C-009…014 M2 settings subset
- [x] ROADMAP formal M0.5 + three-digit T-IDs
- [x] ADR-006 Accepted with pin prerequisite
- [x] noctalia-plugin non-negotiables aligned with gates
- [ ] G-API-1…3 pin (pre-M2)
- [ ] GitHub collector argv values filled (pre-M2)
- [x] Luau test runner ADR-015 (minimal in-repo harness for M1)

## M1 Domain (0.1.0) ✅ closed and tagged `v0.1.0`
- [x] M1.1 Schema — `lib/schema.luau`, `lib/capabilities.luau`, `lib/errors.luau`, `lib/urgency.luau` (PR #2 → `main`)
- [x] M1.2 Aggregator — `lib/aggregator.luau` (merge, filter, counts, isolation, capability honesty) (PR #2 → `main`)
- [x] M1.3 Tests — 42 cases: T-D-001…005, T-A-001…007 (`scripts/run-domain-tests.sh`, CI `domain-tests`) (PR #2 + PR #3)
- [x] M1.4 Stale policy — last-good window + `stale_expired`, retention helper, refresh generations + timeouts (PR #3)
- [x] Review follow-ups — `is_array` empty-table fix; deterministic attention-face tie-break; truthful README badges (`AGENTS.md §13.2`) (PR #2 + PR #3)
- [x] Release PR #4 — `chore(release): 0.1.0` merged, tagged `v0.1.0`, version badge made dynamic



Progress markers per AGENTS.md §13.1: ✅ done (merged + verified) · 🟡 in progress · ⬜ planned



## M2+
- [ ] per ROADMAP after gates

