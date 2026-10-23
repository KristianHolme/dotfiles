-- One set of workspaces (1-10) on the main monitor, one workspace on each
-- other monitor. Replaces Omarchy's per-monitor blocks of ten
-- (default/hypr/monitor-workspaces.lua), which renumbers workspaces on every
-- monitor change.
--
-- Workspace ids stay plain: SUPER + n is workspace n, pinned to the main
-- monitor, so it also pulls focus to that monitor. A side monitor owns the
-- first workspace of its own block (11, 21, ...). Unplugging a monitor lets
-- Hyprland park its workspaces elsewhere and return them under the same id.
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

local main = "eDP-1"
local sides = {}

if hostname() == "bengal" then
	main = "desc:HP Inc. HP E273q"
	sides = {
		"desc:Philips Consumer Electronics Company PHL 241B8Q",
		"desc:Dell Inc. DELL 2001FP",
	}
end

-- Stop Omarchy's reconcile (called from its reload and hotplug hooks).
o.workspaces.reconcile = function() end

for slot = 1, 10 do
	hl.workspace_rule({ workspace = tostring(slot), monitor = main, default = slot == 1 })
end

for index, side in ipairs(sides) do
	hl.workspace_rule({
		workspace = tostring(index * 10 + 1),
		monitor = side,
		default = true,
		persistent = true,
	})
end

for slot = 1, 10 do
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

-- The bar reads this file to learn which block of ten a monitor shows. Main is
-- block 0 and each side monitor gets the block its workspace rule uses.
local function has_prefix(text, prefix)
	return text:sub(1, #prefix) == prefix
end

local function write_bar_blocks()
	local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
	local path = state_home .. "/omarchy/monitor-workspaces"
	local lines = {}

	for _, monitor in ipairs(hl.get_monitors()) do
		local description = monitor.description or ""
		local block = nil
		if main == monitor.name or (main:sub(1, 5) == "desc:" and has_prefix(description, main:sub(6))) then
			block = 0
		else
			for index, side in ipairs(sides) do
				if has_prefix(description, side:sub(6)) then
					block = index
				end
			end
		end
		if block then
			lines[#lines + 1] = block .. "\t" .. monitor.name .. "\t" .. (description ~= "" and description or monitor.name)
		end
	end

	local file = io.open(path, "w")
	if file then
		file:write(table.concat(lines, "\n") .. "\n")
		file:close()
	end
end

hl.on("hyprland.start", write_bar_blocks)
hl.on("config.reloaded", write_bar_blocks)
hl.on("monitor.added", write_bar_blocks)
hl.on("monitor.removed", write_bar_blocks)
