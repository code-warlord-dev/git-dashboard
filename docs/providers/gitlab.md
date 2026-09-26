# Provider: GitLab (P1 / M4)

**Backend:** `glab` CLI  
**Presentation labels:** Merge Requests (MR), pipelines  
**Capability keys:** canonical only (ADR-009)

## Capability honesty (canonical keys)

| Capability | Typical on GitLab |
|------------|-------------------|
| notifications | varies by instance |
| reviews | yes |
| work_items | yes (`kind = merge_request`) |
| issues | yes |
| ci | yes (`kind = ci_run` — pipelines) |
| contributions | events / limited |
| mark_read | varies |

**Forbidden capability keys:** `merge_requests`, `pipelines`, `pull_requests`, `actions`.  
Forge terms appear only in `kind` and UI labels.

## Urgency mapping (summary)

Review requested / assignment → high; pipeline failed on default branch → high; success → low.

## Isolation

Auth failure or rate limit on GitLab MUST NOT clear GitHub data in the Aggregator.

## UI

Tabs: `All | GitHub | GitLab`. Sections mirror GitHub; labels use “Merge requests” / “Pipelines” derived from `kind` + provider.

Full REQ-L-* normative text: **deferred until M4** (SPEC §5 is placeholder “analogous to GitHub” until then). Collector argv freeze same structure as `providers/github.md` §9.
