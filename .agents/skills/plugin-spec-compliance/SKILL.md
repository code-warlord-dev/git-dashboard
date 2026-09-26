---
name: plugin-spec-compliance
description: Review PRs and changes against docs/SPEC.md REQ/T-IDs, ADRs, and Definition of Done. Map every finding to a requirement ID or ADR gap. Use on every PR before merge.
---

# Skill: plugin-spec-compliance

## Non-negotiables

1. Map findings to REQ-* or T-* or ADR number.
2. Reject invented Runtime API usage.
3. Reject provider string branching in UI outside capability helpers.
4. Reject token storage or unredacted logs.
5. Confirm tests exist for touched T-IDs.

## Preferred subagent

Quinn (Reviewer)

## Checklist (Definition of Done)

- [ ] SPEC-compliant or SPEC updated in same PR
- [ ] UI capability-honest
- [ ] Domain free of forge/Noctalia types where required
- [ ] Errors classified correctly
- [ ] No secrets in logs/state
- [ ] PR body lists SPEC IDs
- [ ] CI green when present
