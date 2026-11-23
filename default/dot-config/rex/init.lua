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

-- Logs in to the 2FA SSH masters (uio, saga, olivia, fox) with
-- dotfiles-ssh-login.sh --rex, in the background: ssh asks for passwords and
-- codes in the app's command palette (dotfiles-rex-askpass), and a summary
-- shows there at the end. The action runs on the server of the focused
-- session, so the masters start on that host: bengal or zadkiel.
-- Fain reads key bindings from the local server and runs the action on the
-- focused session's server, so every server needs both.
rex.action{
  name     = "ssh_login",
  title    = "SSH Login (2FA Masters)",
  category = "Scripts",
  keywords = "ssh 2fa controlmaster uio saga olivia fox login",
  run      = function(ctx)
    local h, err = rex.exec.start(
      { os.getenv("HOME") .. "/dotfiles/bin/dotfiles-ssh-login.sh", "--rex" },
      { detach = true, stdout = false, stderr = false, env = { REX_SESSION = ctx.session_id } })
    if not h then error(err, 0) end
    return "logging in"
  end,
}
rex.bind("ctrl+shift+l", "ssh_login")

-- Server-side prompt actions used by dotfiles-rex-askpass and
-- dotfiles-ssh-login.sh --rex (rex.ui prompts run only in server actions,
-- not in client-side `rex do -e` scripts).
rex.action{
  name     = "ssh_askpass",
  title    = "SSH Askpass Prompt",
  category = "Scripts",
  args     = { prompt = "string", host = "string", mode = "string" },
  run      = function(ctx, a)
    local lines = {}
    for l in (a.prompt or ""):gmatch("[^\n]+") do
      l = l:gsub("^%s+", ""):gsub("%s+$", "")
      if l ~= "" then lines[#lines + 1] = l end
    end
    local last = lines[#lines] or ""
    local title = (a.host and a.host ~= "") and ("ssh " .. a.host) or "ssh"

    if (a.prompt or ""):find("(yes/no", 1, true) then
      local fingerprint = ""
      for _, l in ipairs(lines) do
        if l:find("fingerprint is", 1, true) then fingerprint = l end
      end
      local id = rex.ui.pick{
        title = title .. ": unknown host key",
        placeholder = "Trust this host key?",
        items = {
          { id = "yes", title = "Trust and Connect", subtitle = fingerprint, icon = "server" },
          { id = "no", title = "Don't Connect" },
        },
        timeout = 3600,
      }
      return { text = id == "yes" and "yes" or "no" }
    end
    if a.mode == "confirm" or a.mode == "none" then
      local items = a.mode == "none" and { { id = "yes", title = "OK" } }
        or { { id = "yes", title = "Yes" }, { id = "no", title = "No" } }
      local id = rex.ui.pick{ title = title, placeholder = last, items = items, timeout = 3600 }
      if id == "yes" then return { text = "" } end
      return {}
    end
    local text = rex.ui.input{ title = title, placeholder = last, confirm = "Send", timeout = 3600 }
    if text == nil then return {} end
    return { text = text }
  end,
}

rex.action{
  name     = "ssh_login_pick",
  title    = "SSH Login Host Picker",
  category = "Scripts",
  args     = { title = "string", hosts = "string" },
  run      = function(ctx, a)
    local items = {}
    for line in (a.hosts or ""):gmatch("[^\n]+") do
      local host, status = line:match("^([^\t]+)\t?(.*)$")
      if host and host ~= "" then
        items[#items + 1] = {
          id       = host,
          title    = host,
          detail   = status ~= "" and status or nil,
          icon     = "server",
          selected = true,
        }
      end
    end
    local ids = rex.ui.pick{
      title    = a.title,
      multiple = true,
      confirm  = "Log in",
      items    = items,
      timeout  = 3600,
    }
    if ids == nil then return {} end
    return { hosts = ids }
  end,
}

rex.action{
  name     = "ssh_login_summary",
  title    = "SSH Login Summary",
  category = "Scripts",
  args     = { title = "string", detail = "string", retry = "boolean" },
  run      = function(ctx, a)
    local items = { { id = "ok", title = "OK", subtitle = a.detail } }
    if a.retry then
      table.insert(items, 1, { id = "retry", title = "Retry", subtitle = a.detail })
    end
    local id = rex.ui.pick{ title = a.title, items = items, timeout = 3600 }
    return id or "ok"
  end,
}

-- Rebuilds the "monitor" session on zadkiel with dotfiles' rex-monitor: one tab
-- per machine (btop, gmon, slurry, cost, dusage), fox included. Other tabs
-- there, such as "master agent", are kept. Use it after a server restart; a lost connection
-- needs only a login, as the panes reconnect.
rex.action{
  name     = "monitor_rebuild",
  title    = "Rebuild Monitor",
  category = "Scripts",
  keywords = "monitor btop gmon gpu slurry cost dusage machines",
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

-- Opens a tab named HOST with btop (left) and gmon (right) on HOST over SSH,
-- like the GPU machine tabs in the "monitor" session. rex-monitor-ssh
-- reconnects when the host's ControlMaster is down. gmon is in ~/.cargo/bin,
-- which a non-interactive SSH shell does not have on its PATH.
-- Run it from the palette (Fain asks for the host) or `rex do btop_gmon host=ml7`.
rex.action{
  name     = "btop_gmon",
  title    = "btop+gmon",
  category = "Scripts",
  keywords = "monitor ssh host gpu btop gmon",
  args     = { host = "string" },
  run      = function(ctx, args)
    local host = args.host or ""
    if not host:match("^[%w][%w%.%-_@]*$") then error("not a host name: " .. host, 0) end
    local ssh = os.getenv("HOME") .. "/dotfiles/bin/rex-monitor-ssh"
    local shell = "com.superlogical.terminal.shell"
    local w, err = rex.session.new_window{
      window_label = host,
      layout = rex.layout.horizontal(0.58,
        rex.layout.block{ flavor = shell, options = { command = { ssh, host, "btop" } } },
        rex.layout.block{ flavor = shell, options = { command = { ssh, host, "PATH=$HOME/.cargo/bin:$PATH gmon" } } }),
    }
    if err ~= nil then error(err, 0) end
    return { window_id = w.window_id }
  end,
}

-- Returns an action that toggles a floating terminal named `name` running
-- `command` in the active tab. The first press opens it in the focused
-- pane's directory. Later presses hide it when it has focus, and show and
-- focus it when it is hidden or behind. Quitting the program closes it, so the
-- next press opens a new one.
local function float_toggle(name, command)
  return function(ctx)
    local view = rex.call("session.view", { session_id = ctx.session_id })
    local window
    for _, w in ipairs(view.windows or {}) do
      if w.window_id == view.active_window_id then window = w end
    end
    if not window then return "no active tab" end

    for _, layer in ipairs(window.layers or {}) do
      if layer.kind ~= "tiled" then
        for _, b in ipairs(layer.blocks or {}) do
          if b.label == name then
            local hide = layer.state ~= "minimized" and window.focused_block_id == b.block_id
            rex.call("session.set_layer_state", {
              session_id = ctx.session_id, layer_id = layer.layer_id,
              state = hide and "minimized" or "normal", focus = not hide,
            })
            return hide and "hidden" or "shown"
          end
        end
      end
    end

    local cwd = ""
    if ctx.block_id then
      local ok, p = pcall(rex.block.call, "com.superlogical.terminal", "process", { block_id = ctx.block_id })
      if ok and p and p.foreground then cwd = p.foreground.cwd or "" end
    end
    local r, err = rex.session.new_layer{
      bounds = { 0.05, 0.05, 0.9, 0.9 },
      layout = { block = {
        flavor  = "com.superlogical.terminal.shell",
        label   = name,
        options = { command = command, cwd = cwd },
      } },
      focus  = true,
    }
    if err ~= nil then error(err, 0) end
    return r
  end
end

rex.action{
  name     = "float_lazygit",
  title    = "Toggle Floating Lazygit",
  category = "Scripts",
  keywords = "git lazygit float toggle",
  run      = float_toggle("lazygit", { "lazygit" }),
}
rex.bind("ctrl+alt+l", "float_lazygit")

rex.action{
  name     = "float_btop",
  title    = "Toggle Floating btop",
  category = "Scripts",
  keywords = "btop top monitor float toggle",
  run      = float_toggle("btop", { "btop" }),
}
rex.bind("ctrl+alt+b", "float_btop")

rex.action{
  name     = "float_yazi",
  title    = "Toggle Floating Yazi",
  category = "Scripts",
  keywords = "yazi files file manager float toggle",
  run      = float_toggle("yazi", { "yazi" }),
}
rex.bind("ctrl+alt+f", "float_yazi")

-- Live Typst preview beside the editor (github.com/CiaranMcDonnell/rex-typst).
-- The module is a link to a clone and the binary is built per host, so a host
-- without them loads the rest of this file. The key is bound on every host:
-- Fain reads bindings from the local server and runs the action on the
-- focused session's server.
local ok, typst = pcall(require, "rex-typst")
if ok then typst.setup{} end
rex.bind("ctrl+space>t", "typst_toggle")
