-- Keyboard / touchpad overrides. Replaces Omarchy's vconsole + compose:caps defaults.

hl.config({
    input = {
        kb_layout = "no",
        kb_options = "compose:rwin,ctrl:nocaps",
        numlock_by_default = true,
        repeat_rate = 40,
        repeat_delay = 600,
        touchpad = {
            natural_scroll = true,
            clickfinger_behavior = true,
            scroll_factor = 0.4,
        },
    },
})
