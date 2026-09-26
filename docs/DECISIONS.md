# DECISIONS.md — Architecture Decision Records

**Last updated:** 2026-09-26 (M0.5)

Format: short ADR. New design changes require a new ADR + SPEC update in the same PR.

---

## ADR-001 — Multi-provider architecture from day one

**Status:** Accepted  
**Date:** 2026-09-25

**Context:** Users live on GitHub + GitLab + Gitea. Building three separate plugins multiplies maintenance and prevents a unified attention queue.

**Decision:** Provider boundary + normalized model + capability flags are present from the first commit. Delivery is vertical slices: Core+GitHub → GitLab → Gitea → Multi-host.

**Consequences:** UI never branches on provider string outside capabilities/kind. Adding a provider does not rewrite panel code.

---

## ADR-002 — CLI sessions as sole auth

**Status:** Accepted  
**Date:** 2026-09-25

**Context:** Managing PATs inside a shell plugin is a security and UX liability.

**Decision:** Auth is entirely delegated to `gh` / `glab` / `tea`. Plugin never stores tokens. Unauthenticated CLI → `auth_required`.

**Consequences:** Users must have CLIs installed and logged in. Plugin cannot “log you in” itself. This is intentional.

---

## ADR-003 — Capability-honest UI

**Status:** Accepted  
**Date:** 2026-09-25

**Context:** Forges differ. Pretending every forge has Actions produces empty or broken sections.

**Decision:** Every ProviderSnapshot declares capabilities. UI hides or marks unavailable; never shows fake empty feature sections.

**Consequences:** Gitea and limited GitLab instances look “smaller” — that is correct and trustworthy.

---

## ADR-004 — Error taxonomy distinct from auth

**Status:** Accepted  
**Date:** 2026-09-25

**Context:** Mapping every non-zero CLI exit to “logged out” causes data disappearance and user panic on rate limits.

**Decision:** Explicit lifecycle states: `ready`, `auth_required`, `rate_limited`, `network_error`, `api_error`, `bad_response`, `loading`, `unavailable`. Rate-limit and network preserve last-good with `data_state=stale` (ADR-011).

**Consequences:** Collectors and parsers must classify carefully; tests cover the matrix. CLI invoked with `LANG=C LC_ALL=C` where possible to stabilize error text.

---

## ADR-005 — System notifications outside panel

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** Badge-only feedback is easy to miss; unrestricted toasts become noise.

**Decision:** High-urgency events may emit system toasts via documented Noctalia notify API (`noctalia.notify(title, body)`), gated by plugin settings (enabled, min_urgency, dedup, quiet hours). Urgency/dedup/quiet are **plugin policy**, not Noctalia API opts.

**Consequences:** Service owns evaluation; panel remains the triage surface. Click-action on toast is MAY only if Runtime API supports it.

---

## ADR-006 — Argv-only subprocesses

**Status:** Accepted (implementation requires pin supporting argv)  
**Date:** 2026-09-25  
**Updated:** 2026-09-26

**Context:** Shell-string `runAsync` with interpolated user/repo names is an injection risk.

**Decision:** All dynamic CLI invocations MUST use argv-form process execution. Shell-string form is forbidden for dynamic arguments. Current Noctalia public docs document argv tables at `plugin_api = 24`.

**Release gate:** Before M2 ships, pin exact Noctalia tag/commit and confirm argv works on that pin (VERSION-MAP G-API-1/2). If unavailable on the pin, escalate to human — do not fall back to unsafe interpolation.

**Status stability:** Keep this ADR **Accepted**. Adjust only the release-gate / pin notes if docs change — do not flip Accepted ↔ Proposed on every audit pass.

**Consequences:** Slightly more verbose collectors; safer by default. M1 domain does not depend on Runtime API.


---

## ADR-007 — Persistent data directory vs Settings

**Status:** Accepted (wording corrected M0.5)  
**Date:** 2026-09-25  
**Updated:** 2026-09-26

**Context:** Plugin install dir may be replaced on update. User settings are host-managed.

**Decision:**

- **User settings:** declared in `plugin.toml` `[[setting]]`, read via Noctalia config APIs (`getConfig` / equivalent). **Not** stored by the plugin under the data dir as the primary settings store.
- **Runtime persistence** (last-good, dedup, snooze): under the persistent plugin data directory API (confirm exact name `pluginDataDir()` on pinned Noctalia — open gate in VERSION-MAP).

**Consequences:** Cold start can restore last-good; Settings UI stays consistent with Noctalia.

---

## ADR-008 — Named subagents and orchestrator role

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** Large multi-provider work benefits from specialization and short context.

**Decision:** Primary agent is Orchestrator; implementation is delegated to named subagents (Alex, Sam, Jordan, …) with skill-backed briefs. See AGENTS.md.

**Consequences:** Domain changes always go through the flow; small doc typos may be applied directly.

---

## ADR-009 — Canonical capability vocabulary

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** Capability keys are provider-neutral: `notifications`, `reviews`, `work_items`, `issues`, `ci`, `contributions`, `mark_read`. PR vs MR and Actions vs pipelines are expressed via `kind` and UI labels, not capability key names.

**Consequences:** UI can render sections without forge-specific capability branches. See DATA-MODEL.md §2.

---

## ADR-010 — Attention identity and deduplication

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** Each WorkItem has `id` (signal) and `entity_id` (stable work object). `counts.attention` counts **distinct entity_id** with `attention=true`. Overview `attention[]` is entity-level. Multiple signals for one PR count as one badge unit.

**Consequences:** Mark-read is per signal; entity may remain until all attention signals clear. See DATA-MODEL.md §3.

---

## ADR-011 — Stale state model

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** Lifecycle `state` and `data_state` (`fresh` | `stale` | `empty`) are orthogonal. Do **not** use `state = "stale"`. Failed fetch with last-good → e.g. `state=rate_limited`, `data_state=stale`.

**Consequences:** Fewer combinatorial states; clearer banners.

---

## ADR-012 — Persistence and auth invalidation

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** On `auth_required` for a `source_key`: clear memory, invalidate that last-good entry, publish empty privileged lists. Do not restore private last-good until authenticated again. Retention: max age 24h default; max items per kind.

**Consequences:** Prevents private repo metadata flash after logout / account switch.

---

## ADR-013 — Refresh generation / async result ordering

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** Each refresh cycle has a monotonic `refresh_id`. Provider results are tagged with the id that started them. Only results matching the **currently accepted** refresh_id may mutate the published overview. Late results from older generations are discarded. Per-provider timeout (default 30s) and overall refresh budget (default 60s) apply; on timeout treat as `network_error` or keep previous with stale if last-good exists.

**Consequences:** Bounded concurrency cannot overwrite newer state with older CLI output.

---

## ADR-014 — Multi-host state shape from M1

**Status:** Accepted  
**Date:** 2026-09-26

**Decision:** Aggregated overview uses `sources[]` with `source_key = provider|host|account`, not a flat `providers.github` map. M6 host UI is additive, not a schema break.

**Consequences:** Persistence and aggregator designed once. See DATA-MODEL.md §10.


---

## ADR-015 — Luau unit-test runner (M1)

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** M1 requires pure domain tests (T-D-*, T-A-*) with no Noctalia Runtime and no network. Definition of Done demands tests for touched T-IDs. No official Noctalia-bundled Luau test framework is assumed.

**Decision:**

1. **M1 runner:** minimal **in-repo pure Luau test harness** under `tests/` (or `domain/tests/`), invoked by a small shell entrypoint (e.g. `scripts/run-domain-tests.sh` calling `luau` / `lua` with the harness). Assertions: equality, truthy, error expected. Fixtures: JSON/Lua tables for ProviderSnapshots.
2. **No network / no noctalia globals** in domain tests — inject pure functions only.
3. **CI:** when CI exists, run the same shell entrypoint; until then local harness is the DoD gate for M1 PRs.
4. **Future:** may adopt an ecosystem runner (e.g. community Luau test lib) via a new ADR; not required for M1.

**Consequences:** Implementer can write T-D-001… / T-A-001… without waiting for Noctalia pin. Test runner choice is frozen for M1; changing it needs ADR update.
