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

-- Opens a floating terminal that logs in to the 2FA SSH masters (uio, saga,
-- olivia) with dotfiles-ssh-login.sh. The action runs on the server of the
-- focused session, so the masters start on that host: bengal or zadkiel.
-- Fain reads key bindings from the local server only, so every server needs
-- the action, and only bengal's binding is used.
rex.action{
  name     = "ssh_login",
  title    = "SSH Login (2FA Masters)",
  category = "Scripts",
  keywords = "ssh 2fa controlmaster uio saga olivia login",
  run      = function(ctx)
    local r, err = rex.session.new_layer{
      bounds = { 0.15, 0.2, 0.7, 0.6 },
      layout = { block = {
        flavor  = "com.superlogical.terminal.shell",
        label   = "ssh login",
        options = { command = { os.getenv("HOME") .. "/dotfiles/bin/dotfiles-ssh-login.sh", "--pause" } },
      } },
      focus  = true,
    }
    if err ~= nil then error(err, 0) end
    return r
  end,
}
rex.bind("ctrl+shift+l", "ssh_login")

-- Rebuilds the "monitor" session on zadkiel with dotfiles' rex-monitor: one tab
-- per machine (btop, nvidia-smi, slurry, cost, dusage). Other tabs there, such
-- as "master agent", are kept. Use it after a server restart; a lost connection
-- needs only a login, as the panes reconnect.
rex.action{
  name     = "monitor_rebuild",
  title    = "Rebuild Monitor",
  category = "Scripts",
  keywords = "monitor btop nvidia slurry cost dusage machines",
  run      = function(ctx)
    local r, err = rex.session.new_layer{
      bounds = { 0.25, 0.3, 0.5, 0.4 },
      layout = { block = {
        flavor  = "com.superlogical.terminal.shell",
        label   = "rebuild monitor",
        options = { command = { "sh", "-c",
          os.getenv("HOME") .. "/dotfiles/bin/rex-monitor; printf 'Press Enter to close'; read -r _" } },
      } },
      focus  = true,
    }
    if err ~= nil then error(err, 0) end
    return r
  end,
}
