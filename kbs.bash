# kbs — KeyBinding Shortcuts: show this shell's LIVE interactive key bindings
# (atuin · fzf · ble.sh · readline). Must be a shell function: reading the keymap
# needs ble-bind (ble.sh function) / bind (bash builtin), which a child process
# cannot call. Renderer + rules sit beside this file. See `kbs --man`.

kbs() {
    local here awk_f rules userrules
    here="${BASH_SOURCE[0]%/*}"
    awk_f="$here/kbs.awk"
    rules="$here/rules.dat"
    userrules="$HOME/.config/kbs/rules.dat"
    [[ -f $userrules ]] || userrules=/dev/null

    local level=A keymap="" color=auto examples=1 mode=table
    while (( $# )); do
        case $1 in
            -l|--list)     level=A ;;
            -v|--verbose)  level=B ;;
            -vv|--all)     level=C ;;
            -k|--keymap)   shift; keymap=$1 ;;
            --keymap=*)    keymap=${1#*=} ;;
            --no-examples) examples=0 ;;
            --no-color|--no-colour) color=never ;;
            -h|--help)     mode="help" ;;
            --man)         mode="man" ;;
            --)            shift; break ;;
            *) printf 'kbs: unknown option: %s (try: kbs --help)\n' "$1" >&2; return 2 ;;
        esac
        shift
    done

    if [[ ! -f $awk_f ]]; then
        printf 'kbs: renderer not found at %s\n' "$awk_f" >&2; return 1
    fi
    if [[ ! -f $rules ]]; then
        printf 'kbs: rules file not found at %s\n' "$rules" >&2; return 1
    fi

    if [[ $mode == help ]]; then _kbs_help; return 0; fi
    if [[ $mode == man ]]; then
        if [[ -t 1 && $color != never ]]; then
            # shellcheck disable=SC2206  # intentional split: PAGER may be "less -R"
            local -a _pager=( ${PAGER:-less -R} )
            _kbs_man | "${_pager[@]}"
        else
            _kbs_man
        fi
        return 0
    fi

    if [[ -z $keymap ]]; then
        if [[ -o vi ]]; then keymap=vi-insert; else keymap=emacs; fi
    fi

    local cnum=0
    if [[ $color == auto ]]; then
        [[ -t 1 && -z ${NO_COLOR:-} ]] && cnum=1
    fi

    local trigger=${FZF_COMPLETION_TRIGGER:-**}
    local backend
    if [[ ${BLE_ATTACHED-} || ${BLE_VERSION-} ]]; then backend=ble; else backend=readline; fi

    {
        if [[ $backend == ble ]]; then
            printf '## ble %s\n' "$keymap"
            ble-bind --keymap "$keymap" -PD 2>/dev/null
        else
            printf '## readline -p\n'; bind -p 2>/dev/null
            printf '## readline -s\n'; bind -s 2>/dev/null
            printf '## readline -X\n'; bind -X 2>/dev/null
        fi
    } | awk -v rules="$rules" -v userrules="$userrules" \
            -v backend="$backend" -v keymap="$keymap" -v level="$level" \
            -v trigger="$trigger" -v color="$cnum" -v examples="$examples" \
            -v emit=table -f "$awk_f"
}

_kbs_help() {
    cat <<'EOF'
kbs — show this shell's interactive key bindings (atuin · fzf · ble.sh · readline)

Usage: kbs [LEVEL] [options]

Levels:
  (default)        non-default bindings + synthetic rows, enriched & pretty
  -l, --list       same as default (level A)
  -v, --verbose    add notable built-in keys (Tab, arrows, Ctrl-A/E, ...)
  -vv, --all       every binding in the active keymap

Options:
  -k, --keymap N   force a keymap (emacs|vi-insert|vi-command)
  --no-examples    hide the teaching examples footer
  --no-color       plain output (also auto when piped or NO_COLOR set)
  -h, --help       this help
  --man            full man-page-style reference

Reads the live keymap from your shell, so it always reflects reality.
EOF
}

_kbs_man() {
    cat <<'EOF'
NAME
     kbs — KeyBinding Shortcuts: display and learn this shell's key bindings

SYNOPSIS
     kbs [-l | -v | -vv] [-k keymap] [--no-examples] [--no-color]
     kbs -h | --help | --man

DESCRIPTION
     kbs reads the live key bindings of the current interactive shell and prints
     them as a friendly teaching table. It works with both ble.sh (via ble-bind)
     and plain readline (via bind), classifying each binding by source — atuin,
     fzf, ble.sh, or readline — and giving it a human-readable action. Because it
     reads the real keymap, the table can never silently drift from what your keys
     actually do.

OPTIONS
     (no args)      Level A: non-default bindings plus synthetic rows.
     -l, --list     Explicit level A (the default).
     -v, --verbose  Level B: level A plus notable built-in keys.
     -vv, --all     Level C: every binding in the active keymap.
     -k, --keymap N Force keymap emacs, vi-insert, or vi-command (default: auto).
     --no-examples  Suppress the teaching examples footer.
     --no-color     Disable colour (also auto-off when piped or NO_COLOR is set).
     -h, --help     Print concise usage.
     --man          Print this manual.

MODES
     Level A (default) shows only non-default bindings: the -x/-c/-s entries that
     tools and your dotfiles installed (fzf, atuin, custom widgets), plus synthetic
     rows for things that are not keymap bindings such as the fzf ** completion
     trigger. Level B adds an allowlist of notable built-in keys. Level C dumps
     every binding in the active keymap.

RECOGNITION
     fzf bindings name themselves (fzf-file-widget, __fzf_cd__). atuin uses opaque
     macros in its private \C-x\C-_A dispatch namespace, recognised by that
     signature; its internal helper keys are hidden. ble.sh and readline widgets
     are matched by name. Classification is data-driven via rules.dat; unrecognised
     bindings show their raw target, never a guess.

ENVIRONMENT
     FZF_COMPLETION_TRIGGER  The fzf completion trigger (default **).
     NO_COLOR                If set, disables colour.
     PAGER                   Pager used for --man (default: less -R).

FILES
     ~/.local/lib/kbs/kbs.bash   The kbs() shell function (live capture).
     ~/.local/lib/kbs/kbs.awk    The renderer.
     ~/.local/lib/kbs/rules.dat  Default recognition + teaching rules.
     ~/.config/kbs/rules.dat     Optional user overrides (consulted first).

EXIT STATUS
     0 on success; non-zero if no keymap could be read.

EXAMPLES
     kbs              Show what your custom keys do.
     kbs -vv          Audit every binding in the active keymap.
     vim **<Tab>      Use fzf's completion trigger to pick a file.

SEE ALSO
     atuin(1), fzf(1), ble.sh (https://github.com/akinomyoga/ble.sh)

AUTHOR
     kbs — KeyBinding Shortcuts for the interactive shell.
EOF
}
