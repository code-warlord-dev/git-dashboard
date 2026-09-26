---
name: git-dashboard
description: Project contracts for code-warlord-dev/git-dashboard — ProviderSnapshot, Aggregator, capabilities, ROADMAP milestones, SPEC REQ ids. Use when implementing or reviewing core domain, aggregator, or multi-provider behavior.
---

# Skill: git-dashboard

## Non-negotiables

0. Canonical capabilities (ADR-009); attention entity_id (ADR-010); data_state not state=stale (ADR-011); sources[] (ADR-014).


1. UI consumes only normalized model + capabilities — no `if provider == "github"` outside capability helpers.
2. Error taxonomy from `docs/DATA-MODEL.md` — never map all CLI failures to auth_required.
3. Credentials stay with CLI; plugin never stores tokens.
4. One Aggregator; providers produce ProviderSnapshots only.
5. Capability honesty: hide or mark unavailable, never fake empty sections.

## When to load

- Any change to schema, aggregator, attention queue, or provider boundary
- PR review of core or multi-provider behavior
- Planning a new milestone that touches domain

## Key paths

- `docs/SPEC.md` — REQ-D-*, REQ-A-*
- `docs/DATA-MODEL.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/DECISIONS.md` (ADR-001 … ADR-004)

## Done-when checklist

- [ ] SPEC IDs listed
- [ ] Tests for touched T-D / T-A
- [ ] No forge types leaked into aggregator
- [ ] Capability flags consistent with filled data
