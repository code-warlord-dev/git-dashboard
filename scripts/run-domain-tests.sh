#!/usr/bin/env bash
#
# Domain test entrypoint (ADR-015).
#
# Pure Luau/Lua: no Noctalia Runtime, no network, no CLI. Interpreter resolution
# order is $LUA, then luau, lua5.4, lua, luajit — the first one available wins,
# so CI and developer machines can differ without touching the suite.
#
set -euo pipefail

cd "$(dirname "$0")/.."

interpreter="${LUA:-}"
if [ -z "$interpreter" ]; then
  for candidate in luau lua5.4 lua luajit; do
    if command -v "$candidate" >/dev/null 2>&1; then
      interpreter="$candidate"
      break
    fi
  done
fi

if [ -z "$interpreter" ]; then
  echo "run-domain-tests: no luau/lua interpreter found (set LUA=/path/to/interpreter)" >&2
  exit 127
fi

echo "run-domain-tests: interpreter=$interpreter"
exec "$interpreter" tests/run.luau
