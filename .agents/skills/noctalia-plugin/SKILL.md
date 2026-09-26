---
name: noctalia-plugin
description: Noctalia Shell 5 Runtime API, plugin.toml, service/widget/panel entries, ui.*, noctalia.state, persistence dir, runAsync. Use for any plugin scaffold, entry script, or Runtime API question.
---

# Skill: noctalia-plugin

## Non-negotiables

1. Only documented Runtime API calls (docs.noctalia.dev). Never invent methods.
2. `plugin_api` in plugin.toml must cover every feature used on the **pinned** Noctalia. Public docs currently require `plugin_api = 24` for argv-form `runAsync`; confirm on the pin (G-API-1/2) before M2 code.
3. Runtime persistence only under the persistent plugin data directory API (`pluginDataDir()` per current docs — confirm on pin, G-API-3). User settings live in `plugin.toml` + host config APIs, not as primary store in the data dir.
4. Panel open: `noctalia.togglePanel("code-warlord-dev/git-dashboard:panel")`.
5. Dynamic subprocesses: argv table form when available; never shell-interpolate untrusted values.
6. Notify: only `noctalia.notify(title, body)` — no undocumented opts.

## Key anchors (verify on pinned version)

- `noctalia.togglePanel(id)`
- `noctalia.runAsync(cmdOrArgv, cb)` — argv when plugin_api supports it
- `noctalia.state.set / get / watch`
- `noctalia.pluginDataDir()` — persistent data
- `noctalia.setUpdateInterval`
- `noctalia.notify(title, body)` / optional `notifyError`
- `noctalia.getConfig(key)` — declared plugin settings
- `[[panel]]` placement, capture_keys
- `[[setting]]` schema for Settings UI

## When to load

- Scaffolding plugin.toml or entries
- Any service/widget/panel implementation
- IPC / settings / state questions

## Forbidden

- Shell-string runAsync with untrusted interpolation
- Writing under plugin install dir for persistence
- Compositor-specific IPC from plugin code
- QML-era patterns (`pluginApi`, `manifest.json`, `Main.qml`)

## Legacy warning

Do **not** use QML-era plugin documentation. This project targets **Luau Noctalia 5** (`plugin.toml`, `service.luau` / `widget.luau` / `panel.luau`).

## Persistence vs settings

- **Settings:** `plugin.toml` + `getConfig` / host Settings UI  
- **Runtime data:** last-good, dedup, snooze under persistent data dir API
