#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."

N=${BENCH_N:-4000}
GEN=${BENCH_FILE:-tests/.bench.ts}

python3 - "$GEN" "$N" <<'PY'
import sys
path = sys.argv[1]
n = int(sys.argv[2])
lines = []
for i in range(n):
    lines.append(f'function f{i}(a: number, b: number, c: number): number {{')
    lines.append(f'  if (a > b) {{ return a + c; }} else {{ return b * c; }}')
    lines.append('}')
for i in range(n):
    lines.append(f'let v{i}: number = f{i}({i}, {i+1}, {i+2});')
lines.append(f'console.log(v{n-1});')
open(path, 'w').write('\n'.join(lines) + '\n')
PY

bytes=$(wc -c < "$GEN" | tr -d ' ')
printf 'input: %s (%s bytes, %d functions)\n' "$GEN" "$bytes" "$N"

best_ms() {
    local label=$1
    shift
    local best=0
    local i s e ms
    for i in 1 2 3; do
        s=$(date +%s%N)
        "$@" >/dev/null 2>&1 || true
        e=$(date +%s%N)
        ms=$(( (e - s) / 1000000 ))
        if [ "$best" -eq 0 ] || [ "$ms" -lt "$best" ]; then
            best=$ms
        fi
    done
    printf '%-10s %6d ms  (best of 3)\n' "$label" "$best"
}

best_ms tsc-asm ./tsc-asm --noEmit "$GEN"

TSC=${TSC:-}
if [ -z "$TSC" ]; then
    if command -v tsc >/dev/null 2>&1; then
        TSC=$(command -v tsc)
    elif [ -x node_modules/.bin/tsc ]; then
        TSC=node_modules/.bin/tsc
    fi
fi
if [ -n "$TSC" ]; then
    printf 'reference: %s\n' "$TSC"
    best_ms tsc "$TSC" --noEmit --pretty false --strict false "$GEN"
else
    printf 'reference: tsc not found (set TSC=/path/to/tsc)\n'
fi

TSRS=${TSRS:-}
if [ -z "$TSRS" ] && command -v tsrs >/dev/null 2>&1; then
    TSRS=$(command -v tsrs)
fi
if [ -n "$TSRS" ]; then
    printf 'reference: %s\n' "$TSRS"
    best_ms tsrs "$TSRS" --noEmit --strict false "$GEN"
fi

rm -f "$GEN" "${GEN%.ts}.js"
