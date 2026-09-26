# VERSION-MAP.md

| Version | Tag | Milestone | Noctalia / plugin_api | Notes |
|---------|-----|-----------|----------------------|-------|
| 0.0.0 | — | M0 / M0.5 | any | docs + contract hardening |
| 0.1.0 | v0.1.0 | M1 | — | domain lib / aggregator tests |

**Status:** 0.1.0 is on `main` (M1.1–M1.4, PR #2 + PR #3) and documented by release PR
#4. The `v0.1.0` tag is created only on explicit human instruction (AGENTS.md §6.3) on
the release PR merge commit — never from an agent branch.

**After the tag:** switch the README `Version` badge to the dynamic
`github/v/tag/code-warlord-dev/git-dashboard` badge (AGENTS.md §13.2).


| 0.2.0 | v0.2.0 | M2 | **release pin required** | first loadable plugin, GitHub MVP, system notifications |
| 0.3.0 | v0.3.0 | M3 | pin | mark-read, CI section, contributions, keyboard, full settings |
| 0.4.0 | v0.4.0 | M4 | pin | GitLabProvider |
| 0.5.0 | v0.5.0 | M5 | pin | GiteaProvider, full capability honesty |
| 1.0.0 | v1.0.0 | M6 | pin | multi-host, stable contracts |

**Scheme**

- **0.x.y** — pre-1.0; contracts may change with changelog entry (prefer additive).
- **1.x.y** — stable user contracts.
- Plugin (Luau) is always tied to Noctalia `plugin_api` level.

**Host:** Niri (or any compositor Noctalia supports). No Hyprland coupling.

---

## API capability facts (public Noctalia docs — cited)

These are **capability facts**, not a substitute for a release pin.  
**Sources checked 2026-09-26:**

- Runtime API: https://docs.noctalia.dev/noctalia/plugins/development/runtime-api/  
  — `runAsync()` accepts shell string **or** argument array; argument-array form requires `plugin_api = 24`.
- Plugin API versions: https://docs.noctalia.dev/noctalia/plugins/development/plugin-api/  
  — API **24** introduced in Noctalia **v5.0.0-beta.9**: “Argument-array form of noctalia.runAsync() for direct process execution without shell parsing.”

| Fact | Value | Source |
|------|--------|--------|
| argv-form `runAsync(cmdOrArgv, cb)` | requires `plugin_api = 24` | Runtime API + Plugin API Versions pages above |
| API 24 introduced | Noctalia v5.0.0-beta.9 | Plugin API Versions table |
| `noctalia.pluginDataDir()` | persistent plugin data dir | Runtime API (confirm on pin) |
| `noctalia.notify(title, body)` | no opts | Runtime API |
| `noctalia.notifyError(title, body)` | available | Runtime API |
| `noctalia.getConfig(key)` | plugin/entry settings | Manifest & Settings / Runtime API |
| `noctalia.togglePanel(id)` | documented | Runtime API |

Re-verify these URLs if Noctalia docs move; do not treat the table as eternal without re-check on pin.

## Release gates (before M2 code ships)

| Gate | Question | Status |
|------|----------|--------|
| G-API-1 | Exact Noctalia tag/commit for development | pending human |
| G-API-2 | Confirm argv works on that pin (fact: needs plugin_api 24) | pending on pin |
| G-API-3 | Confirm `pluginDataDir()` on that pin | pending on pin |
| G-API-4 | `notify(title, body)` only | accepted as working assumption |

ADR-006 is **Accepted** with implementation prerequisite: target pin must support argv (plugin_api ≥ 24 per docs).
