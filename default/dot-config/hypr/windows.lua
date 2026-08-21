-- Personal window / layer rules. Syntax: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

o.window({ class = "^Google-chrome$", initial_title = "^.*_/$" }, { tile = true })

o.window({ title = "^Floating Terminal$" }, { float = true, center = true, size = { 600, 500 } })

o.window({ class = "^org\\.dotfiles\\.quicknotes$" }, { float = true, center = true, size = { 600, 500 } })

o.window({ class = "^cursor$" }, { workspace = "2" })

o.window({ class = "^md\\.obsidian\\.Obsidian$" }, { workspace = "name:O" })

-- Obsidian sets the Settings title after map, so a static float rule never matches.
-- 1333x1149 on HDMI-A-1 (3840x2160 @ 1.25 → layout 3072x1728).
local OBSIDIAN_SETTINGS_RATIO = { w = 1333 / 3072, h = 1149 / 1728 }

local function monitor_layout_size(mon)
    local scale = mon.scale
    if scale == nil or scale == 0 then
        scale = 1
    end
    local width = mon.width / scale
    local height = mon.height / scale
    local transform = mon.transform or 0
    if transform % 2 == 1 then
        width, height = height, width
    end
    return width, height
end

local function float_obsidian_settings(w)
    if w == nil or w.class ~= "md.obsidian.Obsidian" then
        return false
    end
    local title = w.title or ""
    if title:sub(1, 11) ~= "Settings - " then
        return false
    end
    if not w.floating then
        hl.dispatch(hl.dsp.window.float({ action = "set", window = w }))
    end
    local width = 1333
    local height = 1149
    local mon = w.monitor
    if mon ~= nil then
        local mw, mh = monitor_layout_size(mon)
        width = math.floor((mw * OBSIDIAN_SETTINGS_RATIO.w) + 0.5)
        height = math.floor((mh * OBSIDIAN_SETTINGS_RATIO.h) + 0.5)
    end
    hl.dispatch(hl.dsp.window.resize({
        x = width,
        y = height,
        relative = false,
        window = w,
    }))
    hl.dispatch(hl.dsp.window.center({ window = w }))
    return true
end

hl.on("window.open", function(w)
    if w == nil or w.class ~= "md.obsidian.Obsidian" then
        return
    end
    if float_obsidian_settings(w) then
        return
    end
    local sub
    sub = hl.on("window.title", function(tw)
        if tw == nil or tw.address ~= w.address then
            return
        end
        if float_obsidian_settings(tw) then
            sub:remove()
        end
    end)
    hl.timer(function()
        if sub:is_active() then
            sub:remove()
        end
    end, { timeout = 2000, type = "oneshot" })
end)

o.window({ title = ".*julia Plots.*" }, { tag = "+opaque" })

o.window({ class = "^GLWindow$" }, {
    float = true,
    tag = "-default-opacity",
    opacity = "1.0 override 1.0 override",
})

o.window({ tag = "opaque" }, { opacity = "1.0 override 1.0 override" })

o.window({ class = "^sticky\\.py$" }, { float = true, size = { 300, 250 }, pin = true })

o.window({ class = "^Zotero$", title = "^Citation Dialog$" }, { float = true, center = true })

hl.layer_rule({
    name = "ghostty-quick-terminal",
    match = { namespace = "quickterminal" },
    dim_around = true,
})
