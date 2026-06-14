#!/usr/bin/env bash
# Zero-dependency test harness for kbs. Run: tests/run.sh  (or: make test)
set -u
# CDPATH= guards against a CDPATH in the environment making `cd` print its target,
# which would corrupt these command substitutions.
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT=$(CDPATH= cd -- "$HERE/.." && pwd)
AWK=${AWK:-awk}
FIX="$HERE/fixtures"
# Results go to a temp file so counts survive subshells (piped assertions run in a
# subshell; in-memory counters there would be lost — a false-green hazard).
RESULTS=$(mktemp)
trap 'rm -f "$RESULTS"' EXIT

# render <emit> <backend> <keymap> <level> <color> <examples>   (dump on stdin)
render() {
  "$AWK" -v rules="$ROOT/rules.dat" -v userrules="${KBS_USERRULES:-/dev/null}" \
         -v backend="$2" -v keymap="$3" -v level="$4" -v trigger='**' \
         -v color="$5" -v examples="$6" -v emit="$1" -f "$ROOT/kbs.awk"
}
ble_dump()  { printf '## ble emacs\n'; cat "$FIX/ble_emacs.txt"; }
rl_dump()   { cat "$FIX/readline_raw.txt"; }

ok()   { printf 'p\n' >> "$RESULTS"; }
bad()  { printf 'f\n' >> "$RESULTS"; printf 'FAIL: %s\n' "$1" >&2; }

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

# ---- Task 3: rows pipeline ----
B_A=$(ble_dump | render rows ble emacs A 0 0)
B_B=$(ble_dump | render rows ble emacs B 0 0)
B_C=$(ble_dump | render rows ble emacs C 0 0)
R_A=$(rl_dump  | render rows readline readline A 0 0)

printf '%s' "$B_A" | assert_contains "ble: Ctrl-R is atuin" "Ctrl-R|atuin"
printf '%s' "$B_A" | assert_contains "ble: Up is atuin"     "Up|atuin"
printf '%s' "$B_A" | assert_contains "ble: Ctrl-T is fzf"   "Ctrl-T|fzf"
printf '%s' "$B_A" | assert_contains "ble: Alt-C is fzf"    "Alt-C|fzf"
printf '%s' "$B_A" | assert_contains "ble: Ctrl-Z is ble.sh" "Ctrl-Z|ble.sh"
printf '%s' "$B_A" | assert_contains "ble: synthetic trigger row" "**<Tab>|fzf"
printf '%s' "$B_A" | assert_not_contains "ble: no atuin internals" "__atuin_widget_run"
printf '%s' "$B_A" | assert_not_contains "ble: no C-_ internal keys" "C-_"

printf '%s' "$R_A" | assert_contains "readline: Ctrl-T is fzf" "Ctrl-T|fzf"
printf '%s' "$R_A" | assert_contains "readline: Alt-C is fzf"  "Alt-C|fzf"
printf '%s' "$R_A" | assert_not_contains "readline: no internals" "__atuin_widget_run"

# Up must appear exactly once (atuin wins over the shadowed default)
ups=$(printf '%s\n' "$B_B" | grep -c '^Up|')
assert_eq "ble level B: Up appears once" "1" "$ups"

# level counts increase A < B <= C
ca=$(printf '%s\n' "$B_A" | grep -c '|'); cb=$(printf '%s\n' "$B_B" | grep -c '|'); cc=$(printf '%s\n' "$B_C" | grep -c '|')
[ "$ca" -lt "$cb" ] && ok || bad "level A($ca) < B($cb)"
[ "$cb" -le "$cc" ] && ok || bad "level B($cb) <= C($cc)"

# grep -c already prints 0 (and exits 1) on no matches; capture directly.
PASS=$(grep -c '^p' "$RESULTS"); FAIL=$(grep -c '^f' "$RESULTS")
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
