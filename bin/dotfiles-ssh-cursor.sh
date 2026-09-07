#!/usr/bin/env bash
# SSH wrapper for Cursor Remote-SSH (`remote.SSH.path`).
#
# Do not share ControlMaster with dst/rsync/theme-sync. Cursor recycles its
# tunnel (~5 min here); if it owns the mux, that tear-down drops tmux too.
exec /usr/bin/ssh -o ControlMaster=no -o ControlPath=none "$@"
