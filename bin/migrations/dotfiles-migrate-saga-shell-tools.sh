#!/usr/bin/env bash
# Stop loading Git/tmux module stacks from Saga's local (unstowed) ~/.bashrc.
# Install the official standalone tmux from packages.toml first. Existing shells
# and tmux servers retain their environment; this only changes future startups.
set -Eeuo pipefail

usage() {
    printf 'Usage: %s [--dry-run]\n' "$0"
    printf '\nRemove the three legacy Saga module commands from ~/.bashrc, with a backup.\n'
    printf 'Requires system Git and standalone tmux in the dotfiles install directory.\n'
}

dry_run=0
case "${1:-}" in
    -h | --help)
        usage
        exit 0
        ;;
    --dry-run)
        dry_run=1
        shift
        ;;
esac
if [[ $# -gt 0 ]]; then
    usage >&2
    exit 1
fi

[[ -f "$HOME/.dotfiles-install-env" ]] && . "$HOME/.dotfiles-install-env"
install_dir="${INSTALL_DIR:-$HOME/.local/bin}"
bashrc="$HOME/.bashrc"
if [[ ! -d /cluster/software/git/2.45.1-GCCcore-13.3.0 || ! -f "$bashrc" ]]; then
    printf 'This migration is for the existing Saga shell configuration.\n' >&2
    exit 1
fi
if [[ ! -x /usr/bin/git || ! -x "$install_dir/tmux" ]]; then
    printf 'Install system Git and standalone tmux (%s/tmux) before migrating.\n' "$install_dir" >&2
    exit 1
fi

# Never purge modules here: users may intentionally load them for their work.
# Match only the exact legacy startup commands, leaving all other settings alone.
tmp=$(mktemp "${bashrc}.shell-tools.XXXXXX")
trap 'rm -f -- "$tmp"' EXIT
awk '
    $0 == "module load git/2.45.1-GCCcore-13.3.0" {
        print "# Use system Git and standalone tmux; no shell-wide module dependencies."
        next
    }
    $0 == "module swap ncurses/6.5-GCCcore-13.3.0 ncurses/6.5" { next }
    $0 == "module load tmux/3.4" { next }
    { print }
' "$bashrc" >"$tmp"

if cmp -s "$bashrc" "$tmp"; then
    printf 'No legacy module commands remain; nothing to migrate.\n'
    exit 0
fi
/usr/bin/bash --noprofile --norc -n "$tmp"
if [[ "$dry_run" == 1 ]]; then
    diff -u "$bashrc" "$tmp" || [[ $? == 1 ]]
    exit 0
fi

backup=$(mktemp "${bashrc}.before-shell-tools.XXXXXX")
cp -p -- "$bashrc" "$backup"
chmod --reference="$bashrc" "$tmp"
mv -- "$tmp" "$bashrc"
printf 'Updated %s\nBackup: %s\n' "$bashrc" "$backup"
printf 'Test from a fresh SSH login with a separate server: tmux -L clean new-session -s main\n'
