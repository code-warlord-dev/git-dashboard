# DECISIONS.md — Architecture Decision Records

**Last updated:** 2026-09-26 (ADR-016…018 expert review)

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
**Updated:** 2026-09-26 (expert review — keyboard flow)

**Decision:** On `auth_required` for a `source_key`:
1. Clear **privileged** in-memory items (titles, repos, URLs, account strings for that source).
2. Invalidate matching `last-good.json` entry.
3. Publish overview with `state=auth_required`, `data_state=empty` for that source.
4. Do **not** restore privileged last-good until a successful authenticated fetch.

**May retain in RAM only (non-privileged UI continuity — ADR-018):**
- last focused `entity_id` / section id for panel restore after re-auth;
- UI mode tab (All / provider);
- non-secret settings already known from config.

**Must not retain while `auth_required`:** item titles, repo names, URLs, or any ghost privileged list rows.

Disk retention defaults: max age 24h; max items per kind.

**Consequences:** Privacy preserved; keyboard triage can resume position after re-auth without token storage.

---

## ADR-013 — Refresh generation / async result ordering

**Status:** Accepted  
**Date:** 2026-09-26  
**Updated:** 2026-09-26 (see ADR-017)

**Decision (base + per-source):**
1. Global monotonic `refresh_id` identifies a service refresh cycle.
2. Each **source** tracks `source_refresh_id` (per `source_key`) so a slow source cannot block publishing of faster sources (ADR-017).
3. A result may update that source’s snapshot only if its generation is still the accepted one for that source.
4. Defaults: per-source timeout **30s**; optional **grace** until the next poll tick for a late result of the same source generation (ADR-017). Overall wall budget default **90s**.
5. On hard timeout with no result: `network_error` or keep last-good with `data_state=stale` **for that source only** — other sources stay fresh if they completed.

**Consequences:** No cross-source pollution; fewer false yellow banners from one slow forge.

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

---

## ADR-016 — Urgency-aware toast deduplication

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** A fixed `dedup_minutes = 30` for every event suppresses a second CI failure after a quick failed fix inside the window — the user believes the build is green. Expert review: a uniform window breaks the critical feedback loop.

**Decision:**

1. `notifications.dedup_minutes` (default 30) is the base window for **normal** and **low**.
2. Effective window depends on urgency rank:

| urgency | rank | Default effective window |
|---------|-----:|--------------------------|
| critical | 4 | **5 min** (`notifications.dedup_minutes_critical`) |
| high | 3 | **15 min** (`notifications.dedup_minutes_high`) |
| normal | 2 | `notifications.dedup_minutes` (30) |
| low | 1 | `notifications.dedup_minutes` (30) |

3. Dedup key remains signal `id`. A new CI run with a new native run id is a new `id` and is never suppressed by a previous run’s id. When the forge reuses the same thread id, urgency-aware windows apply.
4. **Digest (F-B1):** when ≥2 high/critical toast-worthy events share `entity_id` or `(kind, repo)` within `digest_window_minutes` (default 10), the service MAY emit one digest toast instead of N singles. Prefer digest under bootloop. Target: M3 (earlier if cheap). Not a blocker for M2 basic toasts.
5. Cold start: still no toast storm for pre-existing unread.

**Consequences:** Critical repeats can surface; routine noise stays filtered. Normative algorithm: `docs/NOTIFICATIONS.md`.

---

## ADR-017 — Per-source refresh and late-result grace

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** Strict global “wait all / discard at 31s” causes yellow banners and hides already-fetched GitHub data when only GitLab is slow (VPN). Expert review: user is punished for minor delay.

**Decision:**

1. **Publish per source as ready:** when source A completes within timeout, Aggregator publishes an updated overview with A’s new snapshot immediately; in-flight sources keep prior snapshot / loading / last-good.
2. **Per-source generation:** in-flight fetch tagged `(global_refresh_id, source_key, source_refresh_id)`. Completing an older `source_refresh_id` after a newer one started for the same source → discard.
3. **Grace:** if the process returns after the 30s timeout but **before the next poll tick** and no newer fetch for that source started, accept the result (quiet UI update).
4. Error banner for a source only if that source has no usable data — not because a sibling is slow.
5. Global `refresh_id` remains for forced refresh and telemetry; it does not force all-or-nothing UI publish.

**Consequences:** Matches error isolation. Softens the strictest early reading of ADR-013 without allowing stale generations to overwrite newer ones.

---

## ADR-018 — Auth recovery UX without plugin tokens

**Status:** Accepted  
**Date:** 2026-09-26

**Context:** ADR-012 correctly clears privileged data on `auth_required`. Expert review: keyboard triage at list position N is destroyed; user must leave the panel, run CLI login elsewhere, return, and re-scroll. Tokens must not return to the plugin.

**Decision:**

1. **Empty auth state remains:** panel shows explicit `auth_required` — no ghost privileged rows.
2. **Hotkey on auth empty state (M3 keyboard; soft-land allowed in M2):** default **`a`** = Authenticate. Argv-only launch of provider login in a terminal (`gh auth login` / `glab auth login` / `tea login`). Prefer `noctalia.runInTerminal` when present on the pinned Runtime API; otherwise documented argv form that opens the user terminal. **No password capture in the plugin.**
3. After terminal session ends, service schedules a refresh; on success, privileged data loads normally.
4. **Navigation restore:** while `auth_required`, panel/service MAY keep in RAM last focused `entity_id` (and optional section id). After re-auth, focus that entity if still present; else list top. Do not write this as a privileged last-good substitute on disk.
5. Optional one-shot high toast on transition to `auth_required`; not a substitute for in-panel recovery.

**Consequences:** Security model unchanged; professional keyboard flow survives session expiry.
