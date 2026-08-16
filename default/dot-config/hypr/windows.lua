-- Personal window / layer rules. Syntax: https://wiki.hypr.land/Configuring/Basics/Window-Rules/

o.window({ class = "^Google-chrome$", initial_title = "^.*_/$" }, { tile = true })

o.window({ title = "^Floating Terminal$" }, { float = true, center = true, size = { 600, 500 } })

o.window({ class = "^org\\.dotfiles\\.quicknotes$" }, { float = true, center = true, size = { 600, 500 } })

o.window({ class = "^cursor$" }, { workspace = "2" })

o.window({ class = "^md\\.obsidian\\.Obsidian$" }, { workspace = "name:O" })

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
