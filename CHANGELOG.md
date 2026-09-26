# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning and milestone mapping: `docs/VERSION-MAP.md`.
Completion of a milestone requires its exit criteria plus a bullet here.

## [Unreleased]

### Changed

- **ADR-016** urgency-aware toast dedup (critical 5m / high 15m / normal·low 30m); digest path F-B1 targeted for M3 (`docs/NOTIFICATIONS.md`, REQ-N-005/009).
- **ADR-017** per-source refresh + late-result grace; overall budget 90s; publish completed sources without waiting on slow peers (REQ-S-005).
- **ADR-018** auth recovery hotkey `a` + in-RAM `entity_id` focus restore; ADR-012 clarified privileged vs non-privileged retention.
- `lib/urgency.luau`: `Urgency.dedup_window_minutes` pure helper for ADR-016.


## [0.1.0] — 2026-09-26

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
- **M1.4 stale policy + refresh generations** — `Schema.POLICY`,
  `Schema.apply_success()` / `Schema.apply_failure()` (last-good window, `stale_expired`,
  clear-on-auth), `Schema.staleness()` banner input, `Schema.should_discard_last_good()`
  retention, `Aggregator:begin_refresh()` / `accepts_generation()` / `publish()` plus
  `PROVIDER_TIMEOUT_SEC` / `REFRESH_BUDGET_SEC`; 13 new cases (T-A-006, T-A-007) —
  **42 passed, 0 failed**.


### Changed

- `docs/DATA-MODEL.md` §2/§6.1 — documented input aliasing and count semantics.
- `docs/ARCHITECTURE.md` §4, `docs/COMPONENTS.md` — actual module layout + M1 status.
- `docs/TRACEABILITY.md` — M1 rows moved `planned` → `covered`; M1.4 ids reserved; known gaps listed.
- `docs/ROADMAP.md` — progress markers legend, milestone/phase status, M1 exit criteria.
- `docs/agent-state/{PROGRESS,SESSION}.md` — kept in sync with `main` after merge.

### Fixed

- `lib/schema.luau` — `is_array` treated an empty table as a non-array (review P2).
- `lib/aggregator.luau` — attention-face selection is now fully order-independent
  (equal rank + equal `updated_at` falls back to the smaller signal id).

### Docs / process

- `AGENTS.md` §13.1 — progress must always be recorded twice: `docs/agent-state/PROGRESS.md`
  **and** the active `docs/ROADMAP.md` phase status / exit criteria; §6.2 got the
  matching Definition-of-Done checkbox, §4 and §12.2 the matching sync step.
- `README.md` — badges (license, domain-tests CI, Lua/Luau, milestone, schema) and a
  title that reflects that the repository now ships implementation, not only docs.



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
