#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."

pass=0
fail=0
for ts in tests/cases/*.ts; do
  base=${ts%.ts}
  name=$(basename "$base")
  expected=""
  [ -f "$base.expected" ] && expected=$(cat "$base.expected")
  rm -f "$base.js"
  actual=$(./tsc-asm "$ts" 2>&1)
  code=$?
  want_code=0
  [ -n "$expected" ] && want_code=2
  ok=1
  if [ "$actual" != "$expected" ]; then
    printf 'FAIL %s: diagnostics differ\n' "$name"
    diff -u <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
    ok=0
  fi
  if [ "$code" -ne "$want_code" ]; then
    printf 'FAIL %s: exit %d, expected %d\n' "$name" "$code" "$want_code"
    ok=0
  fi
  if [ -f "$base.out" ]; then
    if [ ! -f "$base.js" ]; then
      printf 'FAIL %s: no JS emitted\n' "$name"
      ok=0
    else
      got=$(node "$base.js" 2>&1)
      want=$(cat "$base.out")
      if [ "$got" != "$want" ]; then
        printf 'FAIL %s: node output differs\n' "$name"
        diff -u <(printf '%s\n' "$want") <(printf '%s\n' "$got") || true
        ok=0
      fi
    fi
  fi
  if [ "$ok" -eq 1 ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
done
rm -f tests/cases/*.js
printf '%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
