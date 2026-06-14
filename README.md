# kbs — keybinding teaching tool

`kbs` reads your shell's **live** key bindings and prints a friendly table so you can
learn and remember the obscure shortcuts your shell provides (atuin, fzf, ble.sh,
readline). It works under both ble.sh and plain readline, and is zero-dependency:
just bash + awk.

## Install

```sh
git clone <repo> ~/code/kbs
cd ~/code/kbs
make install        # copies to ~/.local/lib/kbs, adds a loader to ~/.bashrc.d
```

Open a new shell, then run `kbs`.

## Usage

```
kbs              # non-default bindings + the ** trigger, with examples
kbs -ll          # + notable built-in keys
kbs -lll         # every binding in the active keymap
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
