# Provider: Gitea (P2 / M5)

**Backend:** `tea` CLI  
**Principle:** Capability honesty first — never pretend feature parity with GitHub.  
**Capability keys:** canonical only (ADR-009)

## Capability honesty (canonical keys)

| Capability | Typical on Gitea |
|------------|------------------|
| notifications | limited |
| reviews | limited |
| work_items | yes (`kind = pull_request`) |
| issues | yes |
| ci | limited / version-dependent (`kind = ci_run` when available) |
| contributions | limited |
| mark_read | limited |

**Forbidden capability keys:** `pull_requests`, `actions`, `pipelines`, `merge_requests`.  
Forge terms only in `kind` and UI labels.

## UI

Tabs include Gitea when enabled. Empty states must not look like “zero items of a supported feature”.

Full REQ-T-* normative text: **deferred until M5**. Collector freeze structure as GitHub §9.
