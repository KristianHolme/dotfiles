-- Move a tab to the front of the tab bar when a program in it reports OSC 7501
-- `state=done`, or goes `working` → `idle` (Claude Code never reports `done`).
-- The active tab is left where it is. Moving never changes focus.
-- Run: rex do --all ~/.config/rex/float-done.lua [app=claude-code]
local only_app = rex.args.app
local last_state = {}

local function window_of(view, block_id)
  for _, window in ipairs(view.windows or {}) do
    for _, layer in ipairs(window.layers or {}) do
      for _, block in ipairs(layer.blocks or {}) do
        if block.block_id == block_id then return window.window_id end
      end
    end
  end
end

local function float_tab(ctx)
  local ok, view = pcall(rex.call, "session.view", { session_id = ctx.session_id })
  if not ok or not view or not view.windows or #view.windows < 2 then return end

  local window_id = window_of(view, ctx.block_id)
  local first_id = view.windows[1].window_id
  if not window_id or window_id == first_id or window_id == view.active_window_id then return end

  pcall(rex.call, "session.move_window", {
    session_id = ctx.session_id, window_id = window_id, before_window_id = first_id,
  })
end

rex.on("com.superlogical.terminal.program_status_changed", function(ctx, event)
  local record = event.record
  if not record then return end

  local key = ctx.block_id .. "/" .. (event.id or "")
  local previous = last_state[key]
  last_state[key] = record.state

  local finished = (record.state == "done" and previous ~= "done")
    or (record.state == "idle" and previous == "working")
  if not finished then return end

  local app = record.effective_app or record.app or ""
  if only_app and app ~= only_app then return end

  float_tab(ctx)
end)

rex.on("com.superlogical.terminal.program_status_removed", function(ctx, event)
  last_state[ctx.block_id .. "/" .. (event.id or "")] = nil
end)
