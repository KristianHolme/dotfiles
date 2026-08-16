-- Personal bindings. Omarchy preinstalled app/webapp chords are disabled in
-- hyprland.lua; core window-manager bindings stay.

local home = os.getenv("HOME") or ""

-- SUPER+CTRL+RETURN is Herdr when preinstalled bindings are on; keep Ghostty QT.
hl.unbind("SUPER + CTRL + RETURN")
o.bind(
    "SUPER + CTRL + RETURN",
    "Quick terminal",
    hl.dsp.global("com.mitchellh.ghostty:CTRL+LOGO+Return")
)

-- Quattro default here is nautilus in the current directory.
hl.unbind("SUPER + SHIFT + ALT + F")
o.bind(
    "SUPER + SHIFT + ALT + F",
    "File manager (floating)",
    "[float;center;size 1000 600] uwsm-app -- nautilus --new-window"
)

-- Quattro preinstalled default is Google Photos; old scratch-nvim chord.
hl.unbind("SUPER + SHIFT + P")
o.bind(
    "SUPER + SHIFT + P",
    "Omawrite (floating)",
    "[float;center;size 600 500] uwsm-app -- omawrite"
)

o.bind(
    "SUPER + less",
    "Obsidian",
    home .. "/dotfiles/bin/dotfiles-cmd-launch-or-focus-class md.obsidian.Obsidian 'uwsm-app -- obsidian'"
)
o.bind(
    "SUPER + Z",
    "Zotero",
    home .. "/dotfiles/bin/dotfiles-cmd-launch-or-focus-zotero 'uwsm-app -- zotero'"
)
o.bind("SUPER + SHIFT + backslash", "Passwords", { launch = "bitwarden-desktop" })

o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })
o.bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })

o.bind("SUPER + SHIFT + G", "Grok", { webapp = "https://grok.com" })
o.bind("SUPER + SHIFT + ALT + G", "Perplexity", { webapp = "https://perplexity.com" })
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com/", focus = true })
o.bind("SUPER + SHIFT + E", "Gmail", { webapp = "https://mail.google.com", focus = true })
o.bind("SUPER + SHIFT + ALT + E", "Outlook", { webapp = "https://outlook.office.com/mail/", focus = true })
o.bind("SUPER + SHIFT + Y", "YouTube", { webapp = "https://youtube.com/" })
o.bind("SUPER + SHIFT + M", "messenger", { webapp = "https://www.messenger.com/", focus = true })
o.bind(
    "SUPER + SHIFT + ALT + M",
    "Google Messages",
    { webapp = "https://messages.google.com/web/conversations", focus = true }
)
o.bind("SUPER + SHIFT + CTRL + M", "Signal", { launch = "signal-desktop", focus = "signal" })
o.bind("SUPER + SHIFT + X", "X", { webapp = "https://x.com/" })
o.bind("SUPER + SHIFT + ALT + X", "X Post", { webapp = "https://x.com/compose/post" })
o.bind("SUPER + SHIFT + T", "To-Do", { webapp = "https://to-do.live.com/tasks/inbox" })
