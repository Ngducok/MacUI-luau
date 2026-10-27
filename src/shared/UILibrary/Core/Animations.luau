local TweenService = game:GetService("TweenService")

local Animations = { reducedMotion = false }

local running = setmetatable({}, { __mode = "k" })

local function cancel(inst: Instance, goal: { [string]: any })
	local props = running[inst]
	if not props then
		return
	end
	for prop in goal do
		local tween = props[prop]
		if tween then
			tween:Cancel()
			props[prop] = nil
		end
	end
end

function Animations.tween(inst: Instance, goal: { [string]: any }, duration: number?, style: Enum.EasingStyle?): Tween?
	cancel(inst, goal)
	if Animations.reducedMotion or not duration or duration <= 0 then
		for prop, value in goal do
			inst[prop] = value
		end
		return nil
	end

	local tween = TweenService:Create(
		inst,
		TweenInfo.new(duration, style or Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		goal
	)
	local props = running[inst] or {}
	running[inst] = props
	for prop in goal do
		props[prop] = tween
	end
	tween:Play()
	return tween
end

function Animations.spin(inst: GuiObject): () -> ()
	if Animations.reducedMotion then
		return function() end
	end
	inst.Rotation = 0
	local tween = TweenService:Create(inst, TweenInfo.new(0.9, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 })
	tween:Play()
	return function()
		tween:Cancel()
		inst.Rotation = 0
	end
end

return Animations
