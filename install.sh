#!/usr/bin/env bash
# Install kbs: copy the runtime files to $PREFIX/lib/kbs (default ~/.local/lib/kbs)
# and drop a loader into ~/.bashrc.d/ that sources them.
set -eu

# Resolve this script's directory (unset CDPATH so `cd` can't print its target).
here=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)

PREFIX=${PREFIX:-$HOME/.local}
libdir=$PREFIX/lib/kbs
loader=$HOME/.bashrc.d/kbs

mkdir -p "$libdir" "$HOME/.bashrc.d"
cp "$here/kbs.bash" "$here/kbs.awk" "$here/rules.dat" "$libdir/"
printf 'source %s/kbs.bash\n' "$libdir" > "$loader"

printf 'kbs installed to %s\n' "$libdir"
printf 'loader written to %s\n' "$loader"
printf 'Open a new shell (or: source %s), then run: kbs\n' "$loader"

# Verify ble.sh actually attaches — kbs needs the live ble.sh keymap. Advisory:
# this never aborts the install (|| true), but warns now if a clobbered
# PROMPT_COMMAND has silently disabled ble.sh, instead of leaving you to discover
# an inert kbs later. Exit codes: 0 ok, 1 clobber, 2 no ble.sh, 77 cannot test.
"$here/check-ble-attach.sh" || true
