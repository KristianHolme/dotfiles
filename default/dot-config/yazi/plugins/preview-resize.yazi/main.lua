--- @since 26.5.6
--- @sync entry

local SCALE = 6
local STEP = 1

local function get()
	local r = rt.mgr.ratio
	if r[1] then
		return { r[1], r[2], r[3] }
	end

	return { r.parent, r.current, r.preview }
end

local function scale(r)
	return { r[1] * SCALE, r[2] * SCALE, r[3] * SCALE }
end

local function apply(parent, current, preview)
	rt.mgr.ratio = { parent, current, preview }
	ya.emit("app:resize", {})
end

local function entry(st, job)
	job = type(job) == "string" and { args = { job } } or job

	if not st.default then
		st.default = scale(get())
		apply(st.default[1], st.default[2], st.default[3])
	end

	local action = job.args[1]
	if action == "reset" then
		apply(st.default[1], st.default[2], st.default[3])
		return
	end

	local parent, current, preview = table.unpack(get())
	if action == "grow" then
		if current <= STEP then
			return
		end
		apply(parent, current - STEP, preview + STEP)
	elseif action == "shrink" then
		if preview <= STEP then
			return
		end
		apply(parent, current + STEP, preview - STEP)
	end
end

return { entry = entry }
