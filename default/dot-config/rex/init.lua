-- Rex configuration: actions, key bindings, and hosts, read by the Rex
-- server. Check it with `rex config check`; apply edits with
-- `rex config reload`.
--
-- Event handlers (rex.on) don't run here: the configuration file is never
-- sent events, only scripts run with `rex do` are.
-- https://www.superlogical.com/rex/docs/automate/lua-events

local config_dir = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/rex"

-- Starts float-done.lua (next to this file) in a detached terminal: it runs in
-- this session but in no tab, and listens to every session. Running the action
-- again while it runs does nothing; after a server restart, which brings the
-- terminal back without the script, it starts the script again.
rex.action{
  name     = "float_done_start",
  title    = "Start Float-Done Watcher",
  category = "Scripts",
  keywords = "agent finished tab front",
  run      = function(ctx)
    -- A server restart brings the terminal back as a plain shell, so look at
    -- what runs in it, not just its label.
    local blocks = rex.session.list_blocks{} or { blocks = {} }
    for _, b in ipairs(blocks.blocks or {}) do
      if b.label == "float-done" then
        local p = rex.block.call("com.superlogical.terminal", "process", { block_id = b.block_id })
        if p and p.foreground and p.foreground.name == "rex" then return "already running" end
        rex.call("block.close", { session_id = ctx.session_id, block_id = b.block_id })
      end
    end
    local r, err = rex.session.new_block{
      flavor  = "com.superlogical.terminal.shell",
      label   = "float-done",
      options = { command = { "rex", "do", "--all", config_dir .. "/float-done.lua" } },
    }
    if err ~= nil then error(err, 0) end
    return r
  end,
}
