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
  if [ "$2" = "$3" ]; then ok; else bad "$1: expected '$2', got '$3'"; fi
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

printf '%s' "$R_A" | assert_contains "readline: Up via -s macro is atuin" "Up|atuin"
printf '%s' "$B_C" | assert_not_contains "level C: targets not single-quoted" "|'"
printf '%s' "$B_C" | assert_contains "level C: BS normalised to Backspace" "Backspace"
printf '%s' "$B_C" | assert_not_contains "level C: no raw BS name" $'\nBS|'

# level counts increase A < B <= C
ca=$(printf '%s\n' "$B_A" | grep -c '|'); cb=$(printf '%s\n' "$B_B" | grep -c '|'); cc=$(printf '%s\n' "$B_C" | grep -c '|')
[ "$ca" -lt "$cb" ] && ok || bad "level A($ca) < B($cb)"
[ "$cb" -le "$cc" ] && ok || bad "level B($cb) <= C($cc)"

# ---- Task 4: table rendering + width invariant + colour ----
T=$(ble_dump | render table ble emacs A 0 0)
printf '%s' "$T" | assert_contains "table has title"  "Keybindings"
printf '%s' "$T" | assert_contains "table has header" "Source"
printf '%s' "$T" | assert_contains "table top border" "┌"

# width invariant: every box-drawing line has equal column count (ambiguous=1)
WIDTHS=$(printf '%s\n' "$T" | grep -E '^[┌│├└]' | LC_ALL=C.UTF-8 awk '{print length}' | sort -u | wc -l)
assert_eq "all box lines share one width" "1" "$WIDTHS"

# colour: present when color=1, absent when color=0
printf '%s' "$(ble_dump | render table ble emacs A 1 0)" | assert_contains "colour on -> ANSI" $'\033[38;5'
printf '%s' "$T" | assert_not_contains "colour off -> no ANSI" $'\033['

# ---- Task 5: examples footer ----
WITH=$(ble_dump | render table ble emacs A 0 1)
WITHOUT=$(ble_dump | render table ble emacs A 0 0)
printf '%s' "$WITH"    | assert_contains   "examples shown when examples=1" "vim **<Tab>"
printf '%s' "$WITHOUT" | assert_not_contains "examples hidden when examples=0" "vim **<Tab>"
printf '%s' "$WITH"    | assert_contains   "examples header" "Examples"

# ---- Task 6: kbs.bash help/man (no live shell needed) ----
HELP=$(bash -c "source '$ROOT/kbs.bash'; kbs --help" 2>&1)
MAN=$(bash -c  "source '$ROOT/kbs.bash'; kbs --man --no-color" 2>&1)
printf '%s' "$HELP" | assert_contains "help shows usage" "Usage: kbs"
printf '%s' "$MAN"  | assert_contains "man NAME"        "NAME"
printf '%s' "$MAN"  | assert_contains "man SYNOPSIS"    "SYNOPSIS"
printf '%s' "$MAN"  | assert_contains "man RECOGNITION" "RECOGNITION"
printf '%s' "$MAN"  | assert_contains "man FILES"       "FILES"
# unknown option exits 2
bash -c "source '$ROOT/kbs.bash'; kbs --bogus" >/dev/null 2>&1
assert_eq "unknown option exits 2" "2" "$?"

# grep -c already prints 0 (and exits 1) on no matches; capture directly.
PASS=$(grep -c '^p' "$RESULTS"); FAIL=$(grep -c '^f' "$RESULTS")
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
