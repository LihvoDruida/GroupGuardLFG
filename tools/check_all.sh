#!/bin/bash
# Повна перевірка: синтаксис, витоки глобалів, тести, бенчмарки.
cd "$(dirname "$0")/.." || exit 1
fail=0
for f in $(find . -name "*.lua" -not -path "./tools/*"); do
  out=$(luac5.1 -p "$f" 2>&1)
  [ -n "$out" ] && { echo "СИНТАКСИС FAIL $f: $out"; fail=1; }
done
for f in $(find . -name "*.lua" -not -path "./tools/*"); do
  out=$(luac5.1 -l -p "$f" 2>/dev/null | grep SETGLOBAL | sed 's/.*; //' | sort -u | grep -v "^SLASH_" | tr '\n' ' ')
  [ -n "$out" ] && { echo "ВИТІК ГЛОБАЛУ $f -> $out"; fail=1; }
done
rm -f luac.out
cd tools || exit 1
lua5.1 tests.lua       || fail=1
lua5.1 tests_extra.lua || fail=1
[ $fail -eq 0 ] && echo "✓ усе чисто" || echo "✗ є проблеми"
exit $fail
