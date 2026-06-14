#!/usr/bin/env bash
# Lint kbs.awk with gawk. Runs the renderer on both fixtures under --lint=fatal, so any
# lint warning (a shadowed local, an uninitialised reference, a bad substr, etc.) becomes
# a non-zero exit. Feeding both fixtures exercises the ble AND readline parser paths.
#
# We RUN the program rather than pretty-print it (`gawk --lint -o`) because that
# combination triggers an internal error in older gawk (e.g. the version on CI runners).
set -eu

here=$(unset CDPATH; cd -- "$(dirname -- "$0")/.." && pwd)

{ printf '## ble emacs\n'; cat "$here/tests/fixtures/ble_emacs.txt" "$here/tests/fixtures/readline_raw.txt"; } \
  | gawk --lint=fatal \
      -v rules="$here/rules.dat" -v userrules=/dev/null \
      -v backend=ble -v keymap=emacs -v level=C -v trigger='**' -v color=1 -v examples=1 -v emit=table \
      -f "$here/kbs.awk" >/dev/null

echo "gawk --lint: clean"
