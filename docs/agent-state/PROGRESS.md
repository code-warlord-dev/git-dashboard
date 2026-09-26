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

## M1 Domain (0.1.0)
- [x] M1.1 Schema — `lib/schema.luau`, `lib/capabilities.luau`, `lib/errors.luau`, `lib/urgency.luau`
- [x] M1.2 Aggregator — `lib/aggregator.luau` (merge, filter, counts, isolation, capability honesty)
- [x] M1.3 Tests (part 1) — 29 cases: T-D-001…005, T-A-001…005 (`scripts/run-domain-tests.sh`, CI `domain-tests`)
- [ ] M1.4 Stale policy window + refresh generation — T-A-006 (`REQ-S-005`/ADR-013), T-A-007 (`REQ-A-009`)
- [ ] M1 exit criteria sign-off + tag `v0.1.0`

## M2+
- [ ] per ROADMAP after gates

