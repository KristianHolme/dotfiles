# SSHFS Mount Templates

Systemd user mount units for auto-mounting remote directories via SSHFS (Tailscale SSH).

## Available Mounts

| Mount File | Remote | Local | User |
|------------|--------|-------|------|
| `mnt-bengal.mount` | bengal:/home/kristian | /mnt/bengal | kristian |
| `mnt-sibir.mount` | sibir:/home/kristian | /mnt/sibir | kristian |
| `mnt-claw.mount` | claw:/home/claw | /mnt/claw | claw |

## Key Options

- `delay_connect` - Mounts on-demand when first accessed (no network until needed)
- `reconnect` - Auto-reconnect after network issues or sleep
- `compression=yes` - Bandwidth-efficient transfers
- `follow_symlinks,transform_symlinks` - Proper symlink handling

## Management

Use the `dotfiles-mounts` TUI to enable/disable:

```bash
dotfiles-mounts              # Interactive toggle
dotfiles-mounts -l           # List status
dotfiles-mounts -a           # Apply config
```

## Adding a New Mount

1. Copy an existing mount file as template
2. Edit `Description`, `What`, and `Where` fields
3. Place in this directory
4. Run `dotfiles-mounts` to enable

## Access

Simply access the mount point to auto-connect:
```bash
ls /mnt/sibir    # First access triggers mount
```
