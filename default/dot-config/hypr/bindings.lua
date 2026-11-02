-- Personal bindings. Omarchy preinstalled app/webapp chords are disabled in
-- hyprland.lua; core window-manager bindings stay.

local home = os.getenv("HOME") or ""

-- SUPER+CTRL+RETURN is Herdr when preinstalled bindings are on; it opens Fain's
-- quick terminal in the middle of the screen instead, and SUPER+CTRL+arrows at
-- each edge. Fain runs the action (`rex do`); its layer rules are
-- in windows.lua.
hl.unbind("SUPER + CTRL + RETURN")
o.bind("SUPER + CTRL + RETURN", "Fain quick terminal", "rex do quick.toggle position=center")
o.bind("SUPER + CTRL + UP", "Fain quick terminal at the top", "rex do quick.toggle position=top")
o.bind("SUPER + CTRL + DOWN", "Fain quick terminal at the bottom", "rex do quick.toggle position=bottom")
-- Omarchy's group focus on these keys is also on SUPER+ALT+TAB / SUPER+ALT+SHIFT+TAB.
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + LEFT", "Fain quick terminal at the left", "rex do quick.toggle position=left")
o.bind("SUPER + CTRL + RIGHT", "Fain quick terminal at the right", "rex do quick.toggle position=right")

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
o.bind("SUPER + SHIFT + P", "Omawrite (floating)", "[float;center;size 600 500] uwsm-app -- omawrite")

o.bind(
	"SUPER + less",
	"Obsidian",
	home .. "/dotfiles/bin/dotfiles-cmd-launch-or-focus-class md.obsidian.Obsidian 'uwsm-app -- obsidian'"
)
o.bind("SUPER + Z", "Zotero", home .. "/dotfiles/bin/dotfiles-cmd-launch-or-focus-zotero 'uwsm-app -- zotero'")
o.bind("SUPER + SHIFT + backslash", "Passwords", { launch = "bitwarden-desktop" })

o.bind("SUPER + ALT + RETURN", "Tmux", { omarchy = "terminal-tmux" })

-- monitors.lua only re-evaluates on config reload (unplug does not switch layouts).
o.bind("SUPER + ALT + R", "Reload Hyprland", "hyprctl reload")
o.bind("SUPER + CTRL + U", "Update Omarchy", "omarchy-launch-floating-terminal-with-presentation omarchy-update")
o.bind("SUPER + SHIFT + D", "Docker", { tui = "lazydocker" })
o.bind("SUPER + D", "Downloads", "omarchy-shell shell toggle jankeesvw.downloads")
o.bind("SUPER + SHIFT + R", "Screen ruler", { panel = "kristianholme.ruler" })

-- Quick agent: Fain's quick pane running the default coding agent
-- (`omarchy agent`), placed like the quick terminal: SUPER+CTRL+ALT+RETURN in
-- the middle of the screen, SUPER+CTRL+ALT+arrows at each edge. SUPER + | (the
-- pipe key) also opens it in the middle. On the Norwegian layout the pipe is
-- the top-left key, XKB name `bar` (not `grave`), so it is bound as SUPER + bar.
-- This replaces Omarchy's Quake console on SUPER + grave.
hl.unbind("SUPER + S")
hl.unbind("SUPER + grave")
hl.unbind("SUPER + SHIFT + grave")
o.bind("SUPER + bar", "Fain quick agent", "rex do quick_agent.toggle position=center")
o.bind("SUPER + CTRL + ALT + RETURN", "Fain quick agent", "rex do quick_agent.toggle position=center")
o.bind("SUPER + CTRL + ALT + UP", "Fain quick agent at the top", "rex do quick_agent.toggle position=top")
o.bind("SUPER + CTRL + ALT + DOWN", "Fain quick agent at the bottom", "rex do quick_agent.toggle position=bottom")
o.bind("SUPER + CTRL + ALT + LEFT", "Fain quick agent at the left", "rex do quick_agent.toggle position=left")
o.bind("SUPER + CTRL + ALT + RIGHT", "Fain quick agent at the right", "rex do quick_agent.toggle position=right")

-- Restored Omarchy 3.x-style fullscreen scratchpad. A second, fullscreen special workspace (special:restored).
-- SUPER+S toggles it; SUPER+ALT+S moves the focused window into it.
hl.workspace_rule({
	workspace = "special:restored",
	gaps_in = 0,
	gaps_out = { top = 0, right = 0, bottom = 0, left = 0 },
	no_border = true,
})
o.bind("SUPER + S", "Fullscreen scratchpad", hl.dsp.workspace.toggle_special("restored"))

-- Override the Omarchy default: SUPER+ALT+S moves the focused window into the
-- fullscreen scratchpad instead of Omarchy's scratchpad.
hl.unbind("SUPER + ALT + S")
o.bind(
	"SUPER + ALT + S",
	"Move to fullscreen scratchpad",
	hl.dsp.window.move({ workspace = "special:restored", follow = false })
)

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
