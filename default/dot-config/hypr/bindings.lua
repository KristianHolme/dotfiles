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
-- Unbind must match Omarchy's string exactly (modifier order matters).
hl.unbind("SUPER + ALT + SHIFT + F")
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

-- Agent console: the Omarchy Quake console (half-screen drop-down that
-- launches the default agent), toggled with SUPER + | (the pipe key).
-- On the Norwegian layout the pipe is the top-left key, XKB name `bar` (not
-- `grave`), so it is bound as SUPER + bar. SUPER + A also toggles it.
hl.unbind("SUPER + S")
hl.unbind("SUPER + grave")
o.bind("SUPER + bar", "Agent console", hl.dsp.workspace.toggle_special("scratchpad"))
o.bind("SUPER + A", "Agent console", hl.dsp.workspace.toggle_special("scratchpad"))

-- Move the focused window into the agent console.
o.bind("SUPER + ALT + bar", "Move to agent console", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- Restored Omarchy 3.x-style fullscreen scratchpad, separate from the agent
-- console. A second, fullscreen special workspace (special:restored).
-- SUPER+S toggles it; SUPER+ALT+S moves the focused window into it.
hl.workspace_rule({
  workspace = "special:restored",
  gaps_in = 0,
  gaps_out = { top = 0, right = 0, bottom = 0, left = 0 },
  no_border = true,
})
o.bind("SUPER + S", "Fullscreen scratchpad", hl.dsp.workspace.toggle_special("restored"))

-- Override the Omarchy default: SUPER+ALT+S previously moved to the agent
-- console; this user wants it to move into the fullscreen scratchpad instead.
hl.unbind("SUPER + ALT + S")
o.bind("SUPER + ALT + S", "Move to fullscreen scratchpad", hl.dsp.window.move({ workspace = "special:restored", follow = false }))

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