#!/usr/bin/env bash
# Zero-dependency test harness for kbs. Run: tests/run.sh  (or: make test)
set -u
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(cd -- "$HERE/.." && pwd)
AWK=${AWK:-awk}
FIX="$HERE/fixtures"
PASS=0 FAIL=0

# render <emit> <backend> <keymap> <level> <color> <examples>   (dump on stdin)
render() {
  "$AWK" -v rules="$ROOT/rules.dat" -v userrules="${KBS_USERRULES:-/dev/null}" \
         -v backend="$2" -v keymap="$3" -v level="$4" -v trigger='**' \
         -v color="$5" -v examples="$6" -v emit="$1" -f "$ROOT/kbs.awk"
}
ble_dump()  { printf '## ble emacs\n'; cat "$FIX/ble_emacs.txt"; }
rl_dump()   { cat "$FIX/readline_raw.txt"; }

ok()   { PASS=$((PASS+1)); }
bad()  { FAIL=$((FAIL+1)); printf 'FAIL: %s\n' "$1" >&2; }

assert_contains() {  # <description> <needle> ; haystack on stdin
  local desc=$1 needle=$2 hay; hay=$(cat)
  case $hay in *"$needle"*) ok ;; *) bad "$desc (missing: $needle)" ;; esac
}
assert_not_contains() {
  local desc=$1 needle=$2 hay; hay=$(cat)
  case $hay in *"$needle"*) bad "$desc (unexpected: $needle)" ;; *) ok ;; esac
}
assert_eq() {  # <description> <expected> <actual>
  if [ "$2" = "$3" ]; then ok; else bad "$3 (expected $2) -- $1"; fi
}

# ---- smoke ----
assert_contains "kbs.awk exists and runs" "Ctrl-R" < <(ble_dump | render rows ble emacs A 0 0)

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
