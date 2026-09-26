<!--
Delivery contract: AGENTS.md §6.1 / §6.2. Keep the section headers, fill every box.
-->

## Summary

<!-- 1 paragraph: what changed and why. Link the milestone phase (e.g. M1.1). -->

## SPEC / ADR references

- REQ-
- ADR-

## Changes

-

## Test plan

- [ ] `scripts/run-domain-tests.sh` (domain, when `lib/` is touched)
- [ ] Smoke checklist (Noctalia entries) — only when `plugin.toml` / entries change
- [ ] Manual: <!-- steps -->

## Definition of Done (AGENTS.md §6.2)

- [ ] SPEC-compliant behavior (or SPEC/ADR updated in this PR)
- [ ] UI never branches on `provider == "..."` outside capability checks
- [ ] Domain / aggregator free of forge-specific types
- [ ] Credentials stay with the CLI; plugin stores no tokens
- [ ] Errors classified (auth vs rate-limit vs network)
- [ ] Tests cover the touched T-IDs (see `docs/TRACEABILITY.md`)
- [ ] Skills / docs updated if the workflow changed
- [ ] CI green

## Migration / risk

<!-- Schema, state key, or settings changes; anything a consumer must know. -->
