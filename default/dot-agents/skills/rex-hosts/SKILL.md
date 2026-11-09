---
name: rex-hosts
description: >-
  Maintain the Rex server setup on bengal and zadkiel (Fain as client): upgrade
  or compare rex versions, restart a server, fix the zadkiel SSH tunnel, add
  another Rex host. Use when Fain cannot reach a host, after a rex package
  update, or before changing any rex-*.service unit.
---

# Rex hosts

Fain (`~/Code/Fain`) is the Linux client for Rex. It reads the host list from
bengal's server and connects to each host itself. Only `rex-hosts` facts that
`rex --help`, the unit files and `rex hosts list` cannot tell you are here.

## Layout

| Host | Server | Reached by |
|---|---|---|
| bengal (this desktop, Arch) | `rex-user.service`: `/usr/bin/rex` from Superlogical's pacman repo, `--tailscale` as `rex-bengal` | Fain via `/run/user/1000/rex/server.sock` |
| zadkiel (UiO, Fedora) | `rex-server.service`: `~/.local/bin/rex`, a copy of bengal's binary, Unix socket only, linger on | `rex-tunnel-zadkiel.service` on bengal: `ssh -L /run/user/1000/rex-tunnels/zadkiel.sock` → `/run/user/293575/rex/server.sock` via `zadkiel-herdr` |
| sibir (Arch) | `rex-user.service` as on bengal, `--tailscale` as `rex-sibir` | Tailscale, `rex-sibir.tail564136.ts.net` |
| bali | its own server | Tailscale, `rex-bali.tail564136.ts.net` |

All three units live in `~/dotfiles/default/dot-config/systemd/user/` and are
stowed to both hosts. Each host enables only its own: bengal `rex-user` and
`rex-tunnel-zadkiel`, zadkiel `rex-server`.

Facts that bite:

- `rex-user.service` names the tailnet node `rex-%l` (short hostname), so the
  same stowed unit gives bengal and sibir separate nodes. A new tsnet node
  logs in once: `rex server status` on that host prints the URL for the user.
  Pull dotfiles there with `git pull --ff-only --no-rebase`, as hosts can have
  uncommitted edits.

- zadkiel's home is NFS, shared with nam-shub and abacus. `rex-server.service`
  has `ConditionHost=zadkiel.uio.no`: the full name, as the short one does not
  match. Keep a host condition on any unit enabled there.
- The tunnel uses BatchMode through the `uio` ControlMaster. With no master it
  fails and restarts every 10 s. The fix is a login: Ctrl+Shift+L in Fain, or
  `~/dotfiles/bin/dotfiles-ssh-login.sh` in a terminal. Never add a password or
  2FA prompt to the unit.
- `~/.config/rex/init.lua` comes from dotfiles and must be the same on every
  server. Fain takes key bindings from bengal's server but runs an action on the
  server of the focused session, so an action missing on zadkiel fails there.
  After an edit: commit, push, `git pull --ff-only` on zadkiel, then
  `rex config reload` on both (`ssh zadkiel-herdr ~/.local/bin/rex config reload`).
- Restarting a server keeps layouts and kills every program in its sessions,
  including agents. zadkiel runs the user's Claude sessions.

## Upgrade

pacman updates `/usr/bin/rex` on bengal, but the running server stays on its
old build until it restarts, and zadkiel keeps its copy until you replace it.

1. Compare: `rex version`, `rex server status | grep -E 'version|api'`,
   `rex -S zadkiel server status | grep -E 'version|api'`. Done when you know
   which servers run an older build than `rex version`.
2. Ask the user before each restart, naming the host. Show what will die:
   `rex -S zadkiel ls`. Proceed only on a yes.
3. zadkiel:
   ```sh
   scp -q /usr/bin/rex zadkiel-herdr:.local/bin/rex.new
   ssh zadkiel-herdr 'chmod 755 ~/.local/bin/rex.new && mv ~/.local/bin/rex.new ~/.local/bin/rex && systemctl --user restart rex-server'
   ```
   bengal: `systemctl --user restart rex-user.service`.
4. Run `rex skill setup` on each upgraded host
   (`ssh zadkiel-herdr ~/.local/bin/rex skill setup`). It updates the installed skill and hook.
5. If `api: revision` changed, check whether Fain still works and rebuild it
   from `~/Code/Fain` (README: Build and run).

Done when `rex -S zadkiel server status` and `rex server status` both print the
version of `rex version`, and `rex -S zadkiel client ls` lists Fain without
`connection lost`.

## Health check

Done when every line below is healthy:

- `rex hosts check`: each host `reachable`.
- bengal: `systemctl --user is-active rex-user rex-tunnel-zadkiel`.
  For tunnel failures: `journalctl --user -u rex-tunnel-zadkiel -n 20`.
  `Permission denied (keyboard-interactive)` means the uio master is down.
- zadkiel: `ssh zadkiel-herdr 'systemctl --user is-active rex-server; loginctl show-user $(id -un) -p Linger'`
  shows `active` and `Linger=yes`.

## Another SSH host

Copy the zadkiel pattern: a socket-only server unit with a `ConditionHost` on
the host, a `rex-tunnel-<host>.service` on bengal, and
`rex hosts add <host> unix:///run/user/1000/rex-tunnels/<host>.sock`. Use the
`<host>-herdr` SSH alias, which has BatchMode. The remote server needs a systemd
user manager and linger; cluster login nodes usually have neither.

## Revert to herdr

On bengal: `systemctl --user disable --now rex-tunnel-zadkiel` and
`rex hosts remove zadkiel`. On zadkiel:
`systemctl --user disable --now rex-server`. Linger can stay on. herdr is
untouched by this setup.

## Monitor session

`~/dotfiles/bin/rex-monitor` builds the `monitor` session on zadkiel: one tab
per machine, its panes running `rex-monitor-ssh HOST CMD`, which reconnects
after a failed connection. The "Rebuild Monitor" action (`init.lua`) runs it.
To change what a machine shows, edit the `tabs`, `first_command` and
`add_splits` in the script; tabs it doesn't name, such as "master agent", are
kept.
