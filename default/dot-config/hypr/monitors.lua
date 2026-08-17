-- Host + connected-display layouts. No stow profiles.
-- List outputs: hyprctl monitors all

local function hostname()
    local file = io.open("/etc/hostname", "r")
    if not file then
        return ""
    end
    local name = file:read("*l") or ""
    file:close()
    return (name:gsub("%s+$", ""))
end

-- Do not call hyprctl from this file: config load runs during `hyprctl reload`
-- and an IPC round-trip deadlocks the compositor. Do not walk hl.get_monitors()
-- either: the keybindings menu stubs `hl` with a table whose __index never
-- returns nil, so ipairs() would allocate forever. DRM EDIDs see every plugged
-- display, including ones currently mirroring.
local function display_inventory()
    local handle = io.popen(
        "for d in /sys/class/drm/card*-*; do"
            .. ' [ -f "$d/status" ] || continue;'
            .. ' [ "$(cat "$d/status")" = connected ] || continue;'
            .. ' strings "$d/edid" 2>/dev/null;'
            .. " printf '\\n';"
            .. " done"
    )
    if not handle then
        return ""
    end
    local inventory = handle:read("*a") or ""
    handle:close()
    return inventory
end

local function has_monitor(needle)
    return display_inventory():find(needle, 1, true) ~= nil
end

local function pin_workspaces(spec)
    for _, item in ipairs(spec) do
        hl.workspace_rule({
            workspace = tostring(item.id),
            monitor = item.monitor,
            persistent = item.persistent == true,
            default = item.default == true,
        })
    end
end

local host = hostname()

if host == "bengal" then
    hl.env("GDK_SCALE", "1")
    hl.monitor({ output = "DP-1", mode = "2560x1440@59.95", position = "0x0", scale = 1 })
    hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@74.97", position = "2560x-310", scale = 1, transform = 3 })
    hl.monitor({ output = "DVI-I-1", mode = "1600x1200@60", position = "-1600x60", scale = 1 })

    pin_workspaces({
        { id = 1, monitor = "DP-1" },
        { id = 2, monitor = "DP-1" },
        { id = 3, monitor = "DP-1" },
        { id = 4, monitor = "DP-1" },
        { id = 5, monitor = "DP-1" },
        { id = 6, monitor = "DP-1" },
        { id = 7, monitor = "HDMI-A-1", persistent = true },
        { id = 8, monitor = "HDMI-A-1", persistent = true },
        { id = 9, monitor = "DVI-I-1", persistent = true },
        { id = 10, monitor = "DVI-I-1", persistent = true },
    })
elseif host == "kaspi" then
    hl.env("GDK_SCALE", "2")
    hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 2 })
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
elseif host == "sibir" then
    hl.env("GDK_SCALE", "1")

    -- Always declare known desks first so a catch-all mirror cannot steal them
    -- on hotplug before layout detection runs.
    hl.monitor({
        output = "desc:Dell Inc. DELL U2424HE",
        mode = "1920x1080@60",
        position = "0x-96",
        scale = 1,
        transform = 3,
    })
    hl.monitor({
        output = "desc:Samsung Electric Company U32E850",
        mode = "3840x2160@60",
        position = "1080x0",
        scale = 1.25,
    })
    hl.monitor({
        output = "desc:Samsung Electric Company C27JG5x H4ZNA00154",
        mode = "2560x1440@60",
        position = "0x0",
        scale = 1,
    })

    if has_monitor("DELL U2424HE") and has_monitor("U32E850") then
        -- Office desk: portrait Dell + Samsung 4K + laptop
        hl.monitor({
            output = "desc:BOE 0x0AFE",
            mode = "2560x1440@60",
            position = "4152x0",
            scale = 2,
        })

        pin_workspaces({
            { id = 1, monitor = "desc:Samsung Electric Company U32E850", persistent = true, default = true },
            { id = 2, monitor = "desc:Samsung Electric Company U32E850", persistent = true },
            { id = 3, monitor = "desc:Samsung Electric Company U32E850", persistent = true },
            { id = 4, monitor = "desc:Samsung Electric Company U32E850", persistent = true },
            { id = 5, monitor = "desc:Samsung Electric Company U32E850", persistent = true },
            { id = 6, monitor = "desc:Samsung Electric Company U32E850", persistent = true },
            { id = 7, monitor = "desc:Dell Inc. DELL U2424HE", persistent = true, default = true },
            { id = 8, monitor = "desc:Dell Inc. DELL U2424HE", persistent = true },
            { id = 9, monitor = "desc:Dell Inc. DELL U2424HE", persistent = true },
            { id = 10, monitor = "desc:BOE 0x0AFE", persistent = true, default = true },
        })
    elseif has_monitor("C27JG5x") then
        -- Other office desk: Samsung 27" + laptop
        hl.monitor({
            output = "desc:BOE 0x0AFE",
            mode = "2560x1440@60",
            position = "-1600x0",
            scale = 1.6,
        })

        pin_workspaces({
            { id = 1, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true, default = true },
            { id = 2, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 3, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 4, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 5, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 6, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 7, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 8, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 9, monitor = "desc:Samsung Electric Company C27JG5x H4ZNA00154", persistent = true },
            { id = 10, monitor = "desc:BOE 0x0AFE", persistent = true, default = true },
        })
    else
        -- Laptop only: scale the panel and mirror unknown extras (projectors)
        hl.monitor({
            output = "desc:BOE 0x0AFE",
            mode = "preferred",
            position = "auto",
            scale = 1.333333,
        })
        hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1, mirror = "eDP-1" })
    end
else
    -- bali and any other host: Quattro generic auto layout
    local omarchy_gdk_scale = 2
    local omarchy_monitor_scale = "auto"
    hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = omarchy_monitor_scale })
end
