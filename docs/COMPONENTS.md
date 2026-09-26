# COMPONENTS.md

See ARCHITECTURE.md for the authoritative layer diagram.

## Entries

| Entry | Responsibility |
|-------|----------------|
| service | Timer, providers, aggregator, state publish, notification evaluate, last-good |
| widget | Badge, tooltip, click → togglePanel |
| panel | Tabs, lists, banners, keyboard, mark-read actions |

## Lib modules

| Module | Role |
|--------|------|
| schema | Validate ProviderSnapshot |
| aggregator | Merge, filter, counts, isolation |
| capabilities | Helpers for UI section visibility |
| badge | Attention → glyph/count |
| format | Relative time, labels |
| notifications | Urgency → toast policy |

## Providers

| Module | CLI | Milestone |
|--------|-----|-----------|
| github.luau | gh | M2 |
| gitlab.luau | glab | M4 |
| gitea.luau | tea | M5 |
