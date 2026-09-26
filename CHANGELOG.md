# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning and milestone mapping: `docs/VERSION-MAP.md`.
Completion of a milestone requires its exit criteria plus a bullet here.

## [Unreleased]

### Added

- **M1.1 domain schema** — `lib/schema.luau` (ProviderSnapshot v1: tolerant
  `normalize`, strict `validate` with error/warn severities, `counts.attention`
  recomputed as a normative invariant, `source_key` identity),
  `lib/capabilities.luau` (canonical capability keys only, input aliasing with a
  report, capability-honest section modes), `lib/errors.luau` (lifecycle error
  taxonomy with documented precedence — a non-zero exit is never "logged out"),
  `lib/urgency.luau` (urgency ranks + deterministic ordering).
- **M1.2 aggregator** — `lib/aggregator.luau`: `DashboardAggregator:merge`
  (0..N snapshots → unified overview in the multi-host `sources[]` shape),
  `Aggregator.filter` (pure tab switching without re-fetch), entity-level
  attention queue, signal counts, per-source capability maps, tab list derived
  from the model, and per-source error isolation (a broken provider degrades to
  `bad_response` + empty data instead of poisoning the dashboard).
- **M1.3 domain tests (part 1)** — `tests/` harness + fixtures per ADR-015, 29
  cases covering T-D-001 … T-D-005 and T-A-001 … T-A-005, the
  `scripts/run-domain-tests.sh` entrypoint and the `domain-tests` CI workflow.
  The suite runs on `luau`, `lua5.4`, `lua` and `luajit` with no Noctalia or
  network access.

### Changed

- `docs/DATA-MODEL.md` §2/§6.1 — documented input aliasing and count semantics.
- `docs/ARCHITECTURE.md` §4, `docs/COMPONENTS.md` — actual module layout + M1 status.
- `docs/TRACEABILITY.md` — M1 rows moved `planned` → `covered`; M1.4 ids reserved.


## [0.0.0] — 2026-09-26

### Added

- M0 Foundations: operating contract — `AGENTS.md` (orchestrator + named
  subagents), `docs/ARCHITECTURE.md`, `docs/DATA-MODEL.md`,
  `docs/COMPONENTS.md`, `docs/SPEC.md` skeleton, `docs/ROADMAP.md`,
  `docs/VERSION-MAP.md`, `docs/NOTIFICATIONS.md`, `docs/FEATURES.md`,
  `docs/SECURITY.md`, `docs/USER.md`, `docs/API.md`, provider docs,
  `diagrams/`, `docs/agent-state/`.
- M0.5 Contract hardening: ADR-009 … ADR-015 (canonical capabilities,
  attention identity, stale state model, persistence/auth invalidation,
  refresh generation, multi-host `sources[]`, Luau test runner),
  `docs/TRACEABILITY.md` living matrix, honest skills inventory,
  plugin id fixed to `code-warlord-dev/git-dashboard`.
- Repository scaffolding: MIT `LICENSE`, `.gitignore`, pull-request template.
