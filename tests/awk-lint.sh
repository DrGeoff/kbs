#!/usr/bin/env bash
# Lint kbs.awk with gawk, using the strongest check the installed gawk supports.
#
# 1. Always: run the renderer on both fixtures under --lint=fatal, so any lint warning
#    (a shadowed local, an uninitialised reference, a bad substr, ...) becomes a non-zero
#    exit. Feeding both fixtures exercises the ble AND readline parser paths. This works
#    on every gawk version.
#
# 2. Additionally, on gawk >= 5.3: the parse-only POSIX lint (--posix --lint=fatal with
#    pretty-print), which also flags non-POSIX constructs. Older gawk hits an internal
#    error on the --lint + pretty-print combination (Op_lint_plus in profile.c), so we
#    detect the version and skip step 2 there rather than crash.
set -eu

here=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)

# 1. Portable run-on-fixtures gate (all gawk versions).
{ printf '## ble emacs\n'; cat "$here/tests/fixtures/ble_emacs.txt" "$here/tests/fixtures/readline_raw.txt"; } \
  | gawk --lint=fatal \
      -v rules="$here/rules.dat" -v userrules=/dev/null \
      -v backend=ble -v keymap=emacs -v level=C -v trigger='**' -v color=1 -v examples=1 -v emit=table \
      -f "$here/kbs.awk" >/dev/null
echo "gawk --lint (run on fixtures): clean"

# 2. Parse-only POSIX lint, only where gawk is new enough to do it without crashing.
ver=$(gawk --version | sed -n '1s/.*[Aa]wk \([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p')
maj=${ver%%.*}
min=${ver#*.}; min=${min%%.*}
if [ -n "$ver" ] && { [ "$maj" -gt 5 ] || { [ "$maj" -eq 5 ] && [ "$min" -ge 3 ]; }; }; then
  gawk --posix --lint=fatal -o/dev/null -f "$here/kbs.awk"
  echo "gawk --posix --lint (parse-only): clean   (gawk $ver)"
else
  echo "gawk --posix --lint (parse-only): skipped (gawk ${ver:-unknown} < 5.3 crashes on --lint + pretty-print)"
fi
