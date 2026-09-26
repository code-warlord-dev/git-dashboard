# API.md — Noctalia Runtime usage (this plugin)

**Plugin id:** `code-warlord-dev/git-dashboard`  
**Required plugin_api:** pin on target Noctalia (intent ≥ level that provides argv process execution; see ADR-006 / VERSION-MAP gate)

## Used Runtime surface (verify on pinned Noctalia before M2 code)

| API | Use | Notes |
|-----|-----|-------|
| `noctalia.togglePanel("code-warlord-dev/git-dashboard:panel")` | Open/close panel from widget | Confirmed in public docs |
| `noctalia.runAsync(...)` | Collectors | Prefer argv table when available on pin; see ADR-006 |
| `noctalia.state.set / get / watch` | Cross-entry dashboard overview | Plain values only |
| Persistent data dir API | last-good, dedup, snooze | Confirm name (`pluginDataDir` vs docs) on pin |
| `noctalia.setUpdateInterval(ms)` | Poll timer | |
| `noctalia.notify(title, body)` | System toasts | **No opts parameter** in documented API |
| `noctalia.notifyError(title, body)` | Error toasts if available | Optional |
| `noctalia.json.encode / decode` | Snapshot IO | |
| `noctalia.log` | Diagnostics (redacted) | |
| Config / settings APIs | Read `[[setting]]` values | Host-managed; not pluginDataDir |

## Entry addresses

- `code-warlord-dev/git-dashboard:service`
- `code-warlord-dev/git-dashboard:widget`
- `code-warlord-dev/git-dashboard:panel`

## State key

`dashboard` — aggregated overview (see DATA-MODEL.md §10).

## Notifications

```lua
noctalia.notify(title, body)
```

Urgency, dedup, quiet hours, and click behavior are **plugin-side policy**. Do not pass undocumented third arguments.

## IPC (user)

```text
noctalia msg panel-toggle code-warlord-dev/git-dashboard:panel
```

### Internal service events (formalize before M3 mark-read)

| Event | Payload (plain table) |
|-------|------------------------|
| `refresh` | `{ reason = "manual" \| "timer" \| "config" }` |
| `mark_read` | `{ source_key, item_id }` |
| `mark_all_read` | `{ source_key, kind? }` |

Do not invent additional IPC verbs until documented here and versioned.

## Legacy warning

Do **not** use QML-era plugin docs (`pluginApi`, `manifest.json`, `Main.qml`). This project is Luau v5 (`plugin.toml`, `service.luau` / `widget.luau` / `panel.luau`).
