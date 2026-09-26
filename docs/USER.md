# USER.md — User-facing contracts

## Install

1. Add plugin source (git or path) in Noctalia Settings → Plugins.
2. Enable `code-warlord-dev/git-dashboard`.
3. Ensure `gh` (and later `glab` / `tea`) is installed and authenticated: `gh auth login`.
4. Optional: bind a key in your compositor to  
   `noctalia msg panel-toggle code-warlord-dev/git-dashboard:panel`

## Widget

Shows attention badge. Click opens the panel.

## Panel

Tabs: **All** | per enabled provider.  
Keyboard (M3): j/k, Enter, m mark-read, o open, Esc close (when capture_keys).

## Notifications

High-urgency events can show desktop toasts. Configure under plugin settings:

- Enable / disable
- Minimum urgency
- Quiet hours
- Dedup window

## Settings (summary)

- enabled_providers
- poll_interval_sec
- notifications.*
- include_contributions
- action_scan_behavior

Full schema in plugin.toml after M3.
