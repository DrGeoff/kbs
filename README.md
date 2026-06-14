# kbs — KeyBinding Shortcuts

`kbs` reads your shell's **live** key bindings and prints a friendly table so you can
learn and remember the obscure shortcuts your shell provides (atuin, fzf, ble.sh,
readline). It works under both ble.sh and plain readline, and is zero-dependency:
just bash + awk.

## Example output

Running `kbs` in a ble.sh shell with atuin and fzf loaded (the table is colour-coded by
source on a real terminal):

```
┌───────────────────────────────────────────────────────────────────┐
│ Keybindings - ble.sh - use -v or -vv for more bindings            │
├─────────┬────────┬────────────────────────────────────────────────┤
│ Key     │ Source │ Action                                         │
├─────────┼────────┼────────────────────────────────────────────────┤
│ **<Tab> │ fzf    │ Fuzzy-completion trigger                       │
│ Ctrl-R  │ atuin  │ History search (fuzzy, synced across machines) │
│ Up      │ atuin  │ History up-search by prefix                    │
│ Alt-C   │ fzf    │ cd into a chosen sub-directory                 │
│ Ctrl-T  │ fzf    │ Pick file(s); insert path at cursor            │
│ Ctrl-Z  │ ble.sh │ Resume the most recent suspended job (fg)      │
└─────────┴────────┴────────────────────────────────────────────────┘
Examples  - fzf ** trigger: type ** where you'd hit Tab
  vim **<Tab>      fuzzy-pick a file to edit
  cd **<Tab>       fuzzy-pick a sub-directory
  ssh **<Tab>      fuzzy-pick a host
  kill -9 **<Tab>  fuzzy-pick a process by PID
  Ctrl-R          search synced history; type to filter, Enter to run
```

## Install

```sh
git clone <repo> ~/code/kbs
cd ~/code/kbs
make install        # copies to ~/.local/lib/kbs, adds a loader to ~/.bashrc.d
```

Open a new shell, then run `kbs`.

### Prerequisite: your `~/.bashrc` must source `~/.bashrc.d/`

`make install` drops a loader at `~/.bashrc.d/kbs`. That loader is only picked up if your
`~/.bashrc` already sources the `~/.bashrc.d/` directory. Many distributions (e.g. Fedora)
ship a `~/.bashrc` that does this by default — it contains something like:

```sh
# User specific aliases and functions
if [ -d ~/.bashrc.d ]; then
    for rc in ~/.bashrc.d/*; do
        [ -f "$rc" ] && . "$rc"
    done
    unset rc
fi
```

If your `~/.bashrc` has no such block, either add the snippet above, or skip the loader
and source kbs directly from `~/.bashrc`:

```sh
source ~/.local/lib/kbs/kbs.bash
```

## Usage

```
kbs              # non-default bindings + the ** trigger, with examples
kbs -v           # + notable built-in keys
kbs -vv          # every binding in the active keymap
kbs --man        # full reference
kbs --help       # quick usage
```

## How it works

A shell function (`kbs.bash`) captures the live keymap — this must run in-process
because `ble-bind`/`bind` are not external commands — and pipes a section-marked dump
to an awk renderer (`kbs.awk`). Recognition and teaching text live in `rules.dat`
(edit it, or override per-user at `~/.config/kbs/rules.dat`).

## Develop / test

```sh
make test           # runs tests/run.sh against committed fixtures
make uninstall
```

## License

BSD 3-Clause License — see [LICENSE](LICENSE). (Same license as
[ble.sh](https://github.com/akinomyoga/ble.sh).)
