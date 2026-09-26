# Changelog

All notable changes to this project are documented in this file.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning and milestone mapping: `docs/VERSION-MAP.md`.
Completion of a milestone requires its exit criteria plus a bullet here.

## [Unreleased]

### Added

- Repository scaffolding for implementation work: `lib/` layout planned in
  `docs/ARCHITECTURE.md` §4, domain test harness per ADR-015 (lands with M1.1/M1.2).

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
