#!/usr/bin/env bash
# Uninstall kbs: remove the installed runtime and the loader.
set -eu

PREFIX=${PREFIX:-$HOME/.local}
libdir=$PREFIX/lib/kbs
loader=$HOME/.bashrc.d/kbs

rm -rf "$libdir"
rm -f  "$loader"
printf 'kbs uninstalled (removed %s and %s)\n' "$libdir" "$loader"
