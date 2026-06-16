#!/usr/bin/env bash
# check-ble-attach.sh — verify ble.sh actually attaches in an interactive shell.
#
# kbs reads the *live* ble.sh keymap, which exists only once ble.sh has attached.
# ble.sh's default --attach=prompt installs its attach hook into PROMPT_COMMAND;
# a startup fragment that reassigns the PROMPT_COMMAND *array* or unsets it (on
# bash<5.1, any scalar reassignment) silently removes that hook and ble.sh never
# attaches. This spawns a real interactive shell and reports the actual result,
# so the breakage is caught at install time, not by a mysteriously inert kbs.
#
# Usage: check-ble-attach.sh [--rcfile PATH] [--quiet]
# Exit:  0 attached OK   1 ble loaded but did NOT attach   2 ble.sh not loaded
#        77 cannot test (no python3 for a pty)
set -u

rcfile=$HOME/.bashrc quiet=
while (($#)); do
  case $1 in
    --rcfile) rcfile=$2; shift 2 ;;
    --rcfile=*) rcfile=${1#*=}; shift ;;
    --quiet) quiet=1; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) printf 'check-ble-attach: unknown arg: %s\n' "$1" >&2; exit 64 ;;
  esac
done
say() { [[ $quiet ]] || printf '%s\n' "$*" >&2; }

command -v python3 >/dev/null 2>&1 ||
  { say "skip: python3 not available (cannot allocate a pty to test attach)"; exit 77; }

KBS_ATTACH_RESULT=$(mktemp) || exit 77
wrap=''
# Register cleanup before the second mktemp so the first temp can't leak if it fails.
trap 'rm -f "$KBS_ATTACH_RESULT" "$wrap"' EXIT
wrap=$(mktemp) || exit 77
export KBS_ATTACH_RESULT KBS_ATTACH_RCFILE="$rcfile"

# Static wrapper rc (quoted heredoc): source the target startup file, then append
# a probe to PROMPT_COMMAND that records ble's attach state on the first prompt.
cat > "$wrap" <<'EOF'
source "$KBS_ATTACH_RCFILE"
__kbs_attach_probe() { printf '%s|%s\n' "${_ble_attached:-0}" "${BLE_VERSION:-}" > "$KBS_ATTACH_RESULT"; }
PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }__kbs_attach_probe"
EOF

# Drive a real interactive shell under a pty; one prompt cycle then exit.
python3 - "$wrap" >/dev/null 2>&1 <<'PYEOF'
import os, pty, select, signal, sys
wrap = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    os.execvp("bash", ["bash", "--rcfile", wrap, "-i"])
try: os.write(fd, b"\n\nexit\n")
except OSError: pass
while True:
    try: r, _, _ = select.select([fd], [], [], 5.0)
    except OSError: break
    if not r: break
    try: d = os.read(fd, 4096)
    except OSError: break
    if not d: break
# Bound the runtime: never block on waitpid. Close the pty (SIGHUPs the child),
# then SIGKILL defensively before reaping, so a startup fragment that blocks the
# first prompt cannot hang this check.
try: os.close(fd)
except OSError: pass
try: os.kill(pid, signal.SIGKILL)
except OSError: pass
try: os.waitpid(pid, 0)
except OSError: pass
PYEOF

# Classify. Exit 1 is intentionally overloaded: it covers BOTH "ble loaded but did
# not attach" (clobber, the final branch) AND "could not confirm" — the test shell
# never produced a first prompt within the ~5s budget (e.g. an unusually slow
# startup). install.sh treats every nonzero exit alike, so the conflation is safe.
line=$(cat "$KBS_ATTACH_RESULT" 2>/dev/null)
attached=${line%%|*} version=${line#*|}
if [[ -z $line ]]; then
  say "WARNING: could not confirm ble.sh attach (the test shell produced no prompt)."
  exit 1
elif [[ -z $version ]]; then
  say "ble.sh is not loaded by your startup files; kbs will use readline bindings."
  exit 2
elif [[ $attached == 1 ]]; then
  say "OK: ble.sh attaches cleanly (version ${version})."
  exit 0
fi
say "WARNING: ble.sh ${version} is loaded but did NOT attach."
say "  A startup fragment reassigns or unsets PROMPT_COMMAND after 'source ble.sh',"
say "  removing ble.sh's deferred-attach hook. Locate it with:"
say "    grep -rn 'PROMPT_COMMAND=' ~/.bashrc ~/.bashrc.d/"
say "  and APPEND (PROMPT_COMMAND+=...) instead of assigning."
exit 1
