---
name: rex-hosts
description: >-
  Maintain the Rex server setup on the user's machines (bengal, sibir, zadkiel,
  bali; Fain as client): upgrade or compare rex versions, restart a server,
  reload config after an init.lua edit, fix the ssh://zadkiel connection, add
  another Rex host. Use when Fain cannot reach a host, an action works on one host but
  not another, after a rex package update, or before changing any rex-*.service
  unit.
---

# Rex hosts

Fain (`~/Code/Fain`) is the Linux client for Rex. Only `rex-hosts` facts that
`rex --help`, the unit files and `rex hosts list` cannot tell you are here.

This skill runs on any of the machines below. Find out which one you are on
with `hostname -s` before you act. "Local" means that machine.

## Layout

| Host | Role | Server | Reached by |
|---|---|---|---|
| bengal (desktop, Arch) | client host | `rex-user.service`: `/usr/bin/rex` from Superlogical's pacman repo, `--tailscale` as `rex-bengal` | local Fain via `/run/user/1000/rex/server.sock` |
| sibir (laptop, Arch) | client host | `rex-user.service` as on bengal, `--tailscale` as `rex-sibir` | local Fain; Tailscale `rex-sibir.tail564136.ts.net` |
| zadkiel (UiO, Fedora) | remote | `rex-server.service`: `~/.local/bin/rex`, a copy of a client host's binary, Unix socket only, linger on | host `ssh://zadkiel` on each client host: Fain (and `rex -S zadkiel`) runs the system ssh, ProxyJump `uio` |
| bali (desktop) | other | its own server | Tailscale, `rex-bali.tail564136.ts.net` |

Fain on a client host reads the host list and key bindings from that host's
own server. All units live in `~/dotfiles/default/dot-config/systemd/user/`
and are stowed everywhere. Each host enables only its own: a client host
enables `rex-user`, and zadkiel enables `rex-server`.

Facts that bite:

- **Reload every server after an `init.lua` edit.** `~/.config/rex/init.lua`
  comes from dotfiles. Each server keeps the config it last loaded until
  `rex config reload`. Fain takes key bindings from the local server, but it
  runs an action on the server of the focused session. If an action is missing
  on that server, its key does nothing there and no error shows. After an edit:
  commit, push, `git pull --ff-only --no-rebase` on each host, then
  `rex -S <host> config reload` for every host in `rex hosts` and
  `rex config reload` for the local server. Done when `rex -S <host> actions`
  lists the action on each host.
- `rex-user.service` names the tailnet node `rex-%l` (short hostname), so the
  same stowed unit gives each client host its own node. A new tsnet node
  logs in once: `rex server status` on that host prints the URL for the user.
  Pull dotfiles with `--ff-only --no-rebase`, as hosts can have uncommitted
  edits.
- zadkiel's home is NFS, shared with nam-shub and abacus. `rex-server.service`
  has `ConditionHost=zadkiel.uio.no`: the full name, as the short one does not
  match. Keep a host condition on any unit enabled there.
- ssh://zadkiel goes through the `uio` jump host, which needs 2FA. Fain runs
  ssh with itself as SSH_ASKPASS, so the password and code questions open in
  Fain's command palette; ssh then leaves a `uio` ControlMaster (4 h
  ControlPersist) that `rex -S zadkiel`, theme sync and rsync reuse. In a
  script or agent shell, use `ssh -o BatchMode=yes zadkiel …`: it works while
  the master is up and fails fast otherwise. The fix for a down master is a
  login: Ctrl+Shift+L in Fain (`ssh_login` action, questions in the palette)
  or `~/dotfiles/bin/dotfiles-ssh-login.sh` in a terminal.
- Restarting a server keeps layouts and kills every program in its sessions,
  including agents. zadkiel runs the user's Claude sessions.

## Upgrade

pacman updates `/usr/bin/rex` on a client host, but the running server stays on
its old build until it restarts, and zadkiel keeps its copy until you replace it.

1. Compare: `rex version`, `rex server status | grep -E 'version|api'`,
   `rex -S zadkiel server status | grep -E 'version|api'`. Done when you know
   which servers run an older build than `rex version`.
2. Ask the user before each restart, naming the host. Show what will die:
   `rex -S zadkiel ls`. Proceed only on a yes.
3. zadkiel, from a client host with the new build:
   ```sh
   scp -q -o BatchMode=yes /usr/bin/rex zadkiel:.local/bin/rex.new
   ssh -o BatchMode=yes zadkiel 'chmod 755 ~/.local/bin/rex.new && mv ~/.local/bin/rex.new ~/.local/bin/rex && systemctl --user restart rex-server'
   ```
   Local client host: `systemctl --user restart rex-user.service`. The other
   client host upgrades itself through pacman; tell the user it needs the same.
4. Run `rex skill setup` on each upgraded host
   (`ssh -o BatchMode=yes zadkiel ~/.local/bin/rex skill setup`). It updates the installed skill and hook.
5. If `api: revision` changed, check whether Fain still works and rebuild it
   from `~/Code/Fain` (README: Build and run).

Done when `rex -S zadkiel server status` and `rex server status` both print the
version of `rex version`, and `rex -S zadkiel client ls` lists Fain without
`connection lost`.

## Health check

Done when every line below is healthy:

- `rex hosts check`: each host `reachable`.
- Local client host: `systemctl --user is-active rex-user`.
  For zadkiel failures: `ssh -O check uio` (no master: log in as above) and
  `journalctl --user -o cat | grep 'ssh tunnel'` for Fain's own ssh errors.
- zadkiel: `ssh -o BatchMode=yes zadkiel 'systemctl --user is-active rex-server; loginctl show-user $(id -un) -p Linger'`
  shows `active` and `Linger=yes`.

## Another SSH host

Copy the zadkiel pattern: a socket-only server unit with a `ConditionHost` on
the host, then `rex hosts add <host> ssh://<ssh alias>` on each client host.
Rex starts the server over ssh when none runs (`rex server start`), but it dies
at logout without linger, so keep the unit. The remote server needs a systemd
user manager and linger; cluster login nodes usually have neither.

## Monitor session

`~/dotfiles/bin/rex-monitor` builds the `monitor` session on zadkiel: one tab
per machine, its panes running `rex-monitor-ssh HOST CMD`, which reconnects
after a failed connection. The "Rebuild Monitor" action (`init.lua`) runs it.
To change what a machine shows, edit the `tabs`, `first_command` and
`add_splits` in the script; tabs it doesn't name, such as "master agent", are
kept.
