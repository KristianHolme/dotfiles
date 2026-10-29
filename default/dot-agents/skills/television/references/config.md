# Television configuration, channels, shell integration

## Files

| Location | Purpose |
|---|---|
| `$XDG_CONFIG_HOME/television/config.toml` or `~/.config/television/config.toml` | Main config |
| `TELEVISION_CONFIG` | If set, config dir is `$TELEVISION_CONFIG` |
| `~/.config/television/cable/*.toml` | Custom channels ("cables") |
| `~/.config/television/themes/` | Custom themes |

Top-level options: `default_channel`, `history_size`, `global_history`, `[ui]`. Full list: [Configuration](https://alexpasmantier.github.io/television/user-guide/configuration/). Override with `--config-file <path>` and `--cable-dir <path>`.

## Custom channel

```toml
# ~/.config/television/cable/example.toml
[metadata]
name = "example"
description = "Short description"

[source]
command = "your-listing-command"

[preview]
command = "preview '{}'"
```

Optional `[keybindings]`, `[actions.*]`. Details: [First channel](https://alexpasmantier.github.io/television/getting-started/first-channel).

## Shell integration

```sh
eval "$(tv init zsh)"      # or bash
tv init fish | source
```

Enables Ctrl+T (smart completion) and Ctrl+R (history). Tune via `[shell_integration]` in `config.toml` (`channel_triggers`, `fallback_channel`, keybindings). Guide: [Shell integration](https://alexpasmantier.github.io/television/user-guide/shell-integration).

## Other

Editors: tv.nvim, tv.vim, VS Code "Television". Install: `pacman -S television`, `brew install television`, `cargo install television`.
