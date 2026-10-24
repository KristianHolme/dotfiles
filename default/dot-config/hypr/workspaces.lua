-- One set of workspaces (1-10) on the main monitor, one workspace on each
-- other monitor. Replaces Omarchy's per-monitor blocks of ten
-- (default/hypr/monitor-workspaces.lua), which renumbers workspaces on every
-- monitor change.
--
-- The main monitor is the first connected display in the host's preference
-- list, else the laptop panel, else any monitor. It is chosen again on every
-- hotplug, so unplugging the preferred display moves 1-10 to the next choice
-- under the same ids. Side monitors own the first workspace of their own block
-- (11, 21, ...), in preference order and then connector order.
-- Reverting: remove require("hypr.workspaces") from hyprland.lua.

local function hostname()
	local file = io.open("/etc/hostname", "r")
	if not file then
		return ""
	end
	local name = file:read("*l") or ""
	file:close()
	return (name:gsub("%s+$", ""))
end

-- Description prefixes, most preferred main first. The rest keep this order for
-- their side workspaces.
local preference = {}

local host = hostname()
if host == "bengal" then
	preference = {
		"HP Inc. HP E273q",
		"Philips Consumer Electronics Company PHL 241B8Q",
		"Dell Inc. DELL 2001FP",
	}
elseif host == "sibir" then
	preference = {
		"Samsung Electric Company U32E850",
		"Samsung Electric Company C27JG5x",
		"Dell Inc. DELL U2424HE",
	}
end

local SLOTS = 10

-- Stop Omarchy's reconcile (called from its reload and hotplug hooks).
o.workspaces.reconcile = function() end

for slot = 1, SLOTS do
	local key = "code:" .. tostring(slot + 9)
	local ws = tostring(slot)
	o.rebind("SUPER + " .. key, "Switch to workspace " .. slot, hl.dsp.focus({ workspace = ws }))
	o.rebind("SUPER + SHIFT + " .. key, "Move window to workspace " .. slot, hl.dsp.window.move({ workspace = ws }))
	o.rebind(
		"SUPER + SHIFT + ALT + " .. key,
		"Move window silently to workspace " .. slot,
		hl.dsp.window.move({ workspace = ws, follow = false })
	)
end

local function rank(monitor)
	local description = monitor.description or ""
	for index, prefix in ipairs(preference) do
		if description:sub(1, #prefix) == prefix then
			return index
		end
	end
	return #preference + 1
end

local function internal(monitor)
	return monitor.name:match("^eDP") or monitor.name:match("^LVDS") or monitor.name:match("^DSI")
end

-- Main first, then the side monitors in side-workspace order. `gone` names a
-- monitor Hyprland still lists while it reports the removal.
local function layout(gone)
	local monitors = {}
	for _, monitor in ipairs(hl.get_monitors()) do
		if not monitor.is_mirror and monitor.name ~= gone then
			monitors[#monitors + 1] = monitor
		end
	end

	table.sort(monitors, function(left, right)
		if rank(left) ~= rank(right) then
			return rank(left) < rank(right)
		end
		if (internal(left) ~= nil) ~= (internal(right) ~= nil) then
			return internal(left) ~= nil
		end
		return left.name < right.name
	end)

	-- Nothing from the list is plugged in: the laptop panel is main.
	if #monitors > 0 and rank(monitors[1]) > #preference then
		for index, monitor in ipairs(monitors) do
			if internal(monitor) then
				table.remove(monitors, index)
				table.insert(monitors, 1, monitor)
				break
			end
		end
	end

	return monitors
end

-- The bar reads this file to learn which block of ten a monitor shows.
local function write_bar_blocks(monitors)
	local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
	local lines = {}
	for index, monitor in ipairs(monitors) do
		local description = monitor.description or ""
		lines[#lines + 1] = (index - 1) .. "\t" .. monitor.name .. "\t" .. (description ~= "" and description or monitor.name)
	end

	local file = io.open(state_home .. "/omarchy/monitor-workspaces", "w")
	if file then
		file:write(table.concat(lines, "\n") .. "\n")
		file:close()
	end
end

-- Show a workspace on a monitor, bringing it over from another or creating it.
local function show(monitor, id)
	local workspace = hl.get_workspace(id)

	if workspace and workspace.monitor and workspace.monitor.name ~= monitor.name then
		hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = monitor.name }))
		workspace = hl.get_workspace(id)
	end

	if workspace then
		monitor:set_workspace({ workspace = workspace.name })
	else
		hl.dispatch(hl.dsp.focus({ monitor = monitor.name }))
		hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
	end
end

local function apply(gone)
	local monitors = layout(gone)
	if #monitors == 0 then
		return
	end

	write_bar_blocks(monitors)

	local main = monitors[1]
	local focused = hl.get_active_monitor()
	local focused_name = focused and focused.name
	local focused_window = hl.get_active_window()

	for slot = 1, SLOTS do
		hl.workspace_rule({ workspace = tostring(slot), monitor = main.name, default = slot == 1 })
	end
	for index = 2, #monitors do
		hl.workspace_rule({
			workspace = tostring((index - 1) * SLOTS + 1),
			monitor = monitors[index].name,
			default = true,
			persistent = true,
		})
	end

	-- Bring existing workspaces to their monitors. A side monitor ends up on its
	-- own workspace, and main on one of 1-10 (the lowest it already shows).
	for slot = 1, SLOTS do
		local workspace = hl.get_workspace(slot)
		if workspace and workspace.monitor and workspace.monitor.name ~= main.name then
			hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(slot), monitor = main.name }))
		end
	end

	for index = 2, #monitors do
		local id = (index - 1) * SLOTS + 1
		local active = monitors[index].active_workspace
		if not active or active.id ~= id then
			show(monitors[index], id)
		end
	end

	local active = main.active_workspace
	if not active or active.id < 1 or active.id > SLOTS then
		local best = 1
		for slot = SLOTS, 1, -1 do
			local workspace = hl.get_workspace(slot)
			if workspace and workspace.monitor and workspace.monitor.name == main.name then
				best = slot
			end
		end
		show(main, best)
	end

	if focused_window and hl.get_window("address:" .. focused_window.address) then
		hl.dispatch(hl.dsp.focus({ window = "address:" .. focused_window.address }))
	elseif focused_name and focused_name ~= gone and hl.get_monitor(focused_name) then
		hl.dispatch(hl.dsp.focus({ monitor = focused_name }))
	end
end

-- Hotplug events arrive in bursts, and Hyprland is still settling its own
-- workspace moves when the first one fires.
local pending = nil
local function schedule(gone)
	pending = gone or pending or false
	hl.timer(function()
		local name = pending or nil
		pending = nil
		apply(name)
	end, { timeout = 400, type = "oneshot" })
end

hl.on("hyprland.start", function() schedule() end)
hl.on("config.reloaded", function() schedule() end)
hl.on("monitor.added", function() schedule() end)
hl.on("monitor.removed", function(monitor) schedule(monitor and monitor.name) end)
