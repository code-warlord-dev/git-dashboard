# TRACEABILITY.md — REQ → Test matrix

**Last updated:** 2026-09-26  
**Grammar:** `T-<AREA>-<NNN>`

**Scope rule (M0.5):** Only M1 domain REQs and frozen M2 REQs need rows here. Remaining REQs are `not-yet-traced` until their collector/UI contract freezes. This is a **living** matrix, not a claim of full coverage.

| Status meaning |
|----------------|
| `planned` | Test ID reserved; case not written yet |
| `covered` | Case written and linked |
| `not-yet-traced` | REQ exists in SPEC; no test row yet |
| `deferred` | Intentionally after later milestone |

| REQ | Test | Milestone | Status |
|-----|------|-----------|--------|
| REQ-D-001 | T-D-001 | M1 | planned |
| REQ-D-002 | T-D-001 | M1 | planned |
| REQ-D-003 | T-D-002 | M1 | planned |
| REQ-D-004 | T-D-003 | M1 | planned |
| REQ-D-005 | T-D-005 | M1 | planned |
| REQ-D-006 | T-D-001, T-D-005 | M1 | planned |
| REQ-D-009 | T-D-002 | M1 | planned |
| REQ-A-001 | T-A-001 | M1 | planned |
| REQ-A-002 | T-A-005 | M1 | planned |
| REQ-A-004 | T-A-002 | M1 | planned |
| REQ-A-006 | T-A-003 | M1 | planned |
| REQ-A-011 | T-A-004 | M1 | planned |
| REQ-S-005 | T-A-006 | M1 | planned |
| REQ-C-009…014 | T-N-001… | M2 | planned |
| REQ-S-007 | T-S-001 | M2 | planned |
| REQ-N-001 | T-N-001 | M2 | planned |
| REQ-N-003 | T-N-003 | M2 | planned |
| REQ-N-005 | T-N-002 | M2 | planned |
| REQ-G-008 | T-G-001 | M2 | planned |
| REQ-G-009 | T-G-002 | M2 | planned |
| REQ-G-013 | T-G-003 | M3 | planned |

Other REQ-* in SPEC: **not-yet-traced** until freeze. Expand rows when cases are written. Never mark REQ done without a defined test when this matrix lists one.
