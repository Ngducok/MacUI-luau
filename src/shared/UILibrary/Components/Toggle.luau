local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Control = require(script.Parent.Control)

local WIDTH, HEIGHT, KNOB = 34, 20, 16

local Toggle = Control.extend("Toggle")

-- Bare switch, reused by card headers. Returns the button and a render(on) function.
function Toggle.switch(colors: { On: any?, Off: any? }?)
	local onToken = colors and colors.On or "Accent"
	local offToken = colors and colors.Off or "SurfaceActive"

	local track = Factory.button({
		Name = "Switch",
		Size = UDim2.fromOffset(WIDTH, HEIGHT),
		BackgroundTransparency = 0,
		Theme = { BackgroundColor3 = offToken },
	}, { Factory.corner(HEIGHT // 2) })

	local knob = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(KNOB, KNOB),
		Parent = track,
		Theme = { BackgroundColor3 = "Knob" },
	}, { Factory.corner(KNOB // 2) })

	local first = true
	local function render(on: boolean)
		local duration = if first then 0 else Theme.Motion.Toggle
		first = false
		local old = track.BackgroundColor3
		Theme.bind(track, { BackgroundColor3 = if on then onToken else offToken })
		local target = track.BackgroundColor3
		track.BackgroundColor3 = old
		Animations.tween(track, { BackgroundColor3 = target }, duration)
		Animations.tween(knob, {
			Position = if on then UDim2.new(1, -KNOB - 2, 0.5, 0) else UDim2.new(0, 2, 0.5, 0),
		}, duration, Enum.EasingStyle.Quart)
	end
	return track, render
end

function Toggle.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Toggle)

	local track, render = Toggle.switch({ On = options.OnColor, Off = options.OffColor })
	track.Parent = self.widget
	self.track = track

	self:bind(options.Default == true, render)
	self.cleanup:connect(track.Activated, function()
		if not self.disabled then
			self:SetValue(not self:GetValue())
		end
	end)

	self:register("toggle switch")
	return self
end

function Toggle:normalize(value)
	return value == true
end

function Toggle:stateText()
	return if self:GetValue() then "On" else "Off"
end

return Toggle
