local Util = {}

function Util.safeCall(fn: ((...any) -> ())?, ...: any)
	if not fn then
		return
	end
	task.spawn(function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			warn(`[MacUI] callback error: {err}`)
		end
	end, ...)
end

function Util.decimals(step: number): number
	local text = tostring(step)
	local dot = string.find(text, ".", 1, true)
	return if dot then #text - dot else 0
end

function Util.snap(value: number, min: number, max: number, step: number?): number
	local size = if step and step > 0 then step else 1
	local snapped = math.clamp(min + math.round((value - min) / size) * size, min, max)
	local factor = 10 ^ Util.decimals(size)
	return math.round(snapped * factor) / factor
end

function Util.format(value: number, step: number?): string
	return string.format(`%.{Util.decimals(step or 1)}f`, value)
end

function Util.merge(base: { [any]: any }, extra: { [any]: any }?): { [any]: any }
	local out = table.clone(base)
	for key, value in extra or {} do
		out[key] = value
	end
	return out
end

function Util.trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

return Util
