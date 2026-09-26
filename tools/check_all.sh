#!/bin/bash
# Full addon verification: Lua syntax, accidental globals, tests.
set -u
cd "$(dirname "$0")/.." || exit 1

fail=0

LUAC="${LUAC:-}"
LUA="${LUA:-}"

if [ -z "$LUAC" ]; then
  for candidate in luac5.1 luac; do
    if command -v "$candidate" >/dev/null 2>&1; then LUAC="$candidate"; break; fi
  done
fi
if [ -z "$LUA" ]; then
  for candidate in lua5.1 lua; do
    if command -v "$candidate" >/dev/null 2>&1; then LUA="$candidate"; break; fi
  done
fi

if [ -z "$LUAC" ] || [ -z "$LUA" ]; then
  echo "Lua 5.1 runtime/compiler is required (lua5.1 + luac5.1)."
  exit 2
fi

while IFS= read -r -d '' f; do
  if ! "$LUAC" -p "$f" >/dev/null 2>&1; then
    echo "SYNTAX FAIL $f"
    "$LUAC" -p "$f" 2>&1 || true
    fail=1
  fi
done < <(find . -name "*.lua" -not -path "./tools/*" -print0)

while IFS= read -r -d '' f; do
  out=$("$LUAC" -l -p "$f" 2>/dev/null | grep SETGLOBAL | sed 's/.*; //' | sort -u | grep -v '^SLASH_' | tr '\n' ' ' || true)
  if [ -n "$out" ]; then
    echo "GLOBAL LEAK $f -> $out"
    fail=1
  fi
done < <(find . -name "*.lua" -not -path "./tools/*" -print0)

rm -f luac.out
(
  cd tools || exit 1
  "$LUA" tests.lua
) || fail=1
(
  cd tools || exit 1
  "$LUA" tests_extra.lua
) || fail=1
(
  cd tools || exit 1
  "$LUA" tests_lfgfilters_forever.lua
) || fail=1

[ "$fail" -eq 0 ] && echo "✓ all checks passed" || echo "✗ checks failed"
exit "$fail"
