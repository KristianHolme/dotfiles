-- Learn how to configure Hyprland: https://wiki.hypr.land/Configuring/Start/

dofile((os.getenv("OMARCHY_PATH") or "/usr/share/omarchy") .. "/default/hypr/bootstrap.lua")

-- Drop HEY/ChatGPT/Spotify/1Password/etc. defaults; we bind our own apps below.
omarchy_preinstalled_bindings = false

require("default.hypr.omarchy")

require("hypr.monitors")
require("hypr.input")
require("hypr.bindings")
require("hypr.looknfeel")
require("hypr.autostart")
require("hypr.windows")

require("default.hypr.toggles")

-- Hyprland's color-management pipeline dithered 8-bit HDMI on the
-- Samsung U32E850 and showed up as strobing (worse when dimmed).
hl.config({
    render = {
        cm_enabled = false,
    },
})
