---
name: television
description: Uses Television (tv), a fast terminal fuzzy finder with channels, previews, and shell integration. Use when the user mentions Television, tv, fuzzy finding files or text, channel configuration, cable.toml channels, piping into a picker, or replacing fzf/telescope-style workflows in the shell.
---

# Television (`tv`)

[Television](https://github.com/alexpasmantier/television) is a Rust TUI fuzzy finder; the executable is `tv`. Docs: [alexpasmantier.github.io/television](https://alexpasmantier.github.io/television/). Run `tv --help` for flags and `tv list-channels` for channels (`tv update-channels` refreshes them).

```sh
tv [CHANNEL] [PATH]    # e.g. tv files, tv text (ripgrep), tv git-repos, tv env
```

## Piping and scripts

Stdin becomes the source list; selected lines go to stdout. Tab toggles multi-select; Enter prints all selected.

```sh
git log --oneline | tv
nvim "$(tv files)"
```

Automation flags: `--select-1`, `--take-1`, `--take-1-fast`, `--expect`, `-i/--input` (prefill query), `--exact` (substring matching).

## Query syntax

`foo` fuzzy, `'foo` substring, `^foo` prefix, `foo$` suffix, `!foo` negate. Space-separated tokens are AND: `test ^src !.bak$`.

## Ad-hoc channel from CLI

```sh
tv --source-command "fd -t f" --preview-command "bat -n --color=always '{}'" --preview-size 70
```

`{}` is the selected entry; `{0}` `{1}` split by `--source-entry-delimiter`. `--ansi` for colored sources, `--no-sort` keeps source order. Keybinding overrides: `tv -k 'quit="esc";select_next_entry=["down","ctrl-j"]'` or `[keybindings]` in config.

## More

- Config files, custom channels (cable TOML), shell integration (`tv init`), install, editors → [references/config.md](references/config.md)
- Stuck → [Tips and tricks](https://alexpasmantier.github.io/television/advanced/tips-and-tricks)
