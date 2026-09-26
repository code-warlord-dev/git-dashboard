# COMPONENTS.md

See ARCHITECTURE.md for the authoritative layer diagram.

## Entries

| Entry | Responsibility |
|-------|----------------|
| service | Timer, providers, aggregator, state publish, notification evaluate, last-good |
| widget | Badge, tooltip, click → togglePanel |
| panel | Tabs, lists, banners, keyboard, mark-read actions |

## Lib modules

| Module | Role | Status |
|--------|------|--------|
| schema | Validate + normalize ProviderSnapshot | M1 ✅ |
| aggregator | Merge, filter, counts, isolation | M1 ✅ |
| capabilities | Helpers for UI section visibility | M1 ✅ |
| errors | Lifecycle error taxonomy | M1 ✅ |
| urgency | Urgency ranks + ordering | M1 ✅ |
| badge | Attention → glyph/count | M2 |
| format | Relative time, labels | M2 |
| notifications | Urgency → toast policy | M2 |

`tests/` + `scripts/run-domain-tests.sh` cover the M1 modules (ADR-015) and run
without Noctalia or network access.


## Providers

| Module | CLI | Milestone |
|--------|-----|-----------|
| github.luau | gh | M2 |
| gitlab.luau | glab | M4 |
| gitea.luau | tea | M5 |
