local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Input = require(Core.Input)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)

local TRACK_WIDTH = 150

local Slider = Control.extend("Slider")

function Slider.new(ctx, parent, options)
	local min, max = options.Min or 0, options.Max or 100
	assert(max > min, "Slider Max must be greater than Min")
	local step = options.Step or 1
	local suffix = options.Suffix or ""

	local self = setmetatable(Control.new(ctx, parent, options), Slider)
	self.min, self.max, self.step = min, max, step

	local value = Factory.text({
		Name = "Value",
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.fromOffset(44, 20),
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})

	local hit = Factory.button({
		Name = "Track",
		Size = UDim2.fromOffset(TRACK_WIDTH, 20),
		LayoutOrder = 2,
		Parent = self.widget,
	})

	local rail = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 4),
		Parent = hit,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(2) })

	local fill = Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		Parent = rail,
		Theme = { BackgroundColor3 = options.Color or "Accent" },
	}, { Factory.corner(2) })

	local thumb = Factory.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Parent = hit,
		Theme = { BackgroundColor3 = "Knob" },
	}, { Factory.corner(7), Factory.stroke("Border", 0.3) })

	local dragging = false
	local function render(v: number)
		local alpha = (v - min) / (max - min)
		local duration = if dragging then 0 else Theme.Motion.Toggle
		Animations.tween(fill, { Size = UDim2.fromScale(alpha, 1) }, duration)
		Animations.tween(thumb, { Position = UDim2.fromScale(alpha, 0.5) }, duration)
		value.Text = Util.format(v, step) .. suffix
	end

	self:bind(Util.snap(options.Default or min, min, max, step), render)

	local function fromPoint(point: Vector2)
		local alpha = math.clamp((point.X - hit.AbsolutePosition.X) / hit.AbsoluteSize.X, 0, 1)
		self:SetValue(min + alpha * (max - min))
	end

	self.cleanup:connect(hit.InputBegan, function(input)
		if self.disabled or not Input.isPointer(input) then
			return
		end
		dragging = true
		Animations.tween(thumb, { Size = UDim2.fromOffset(16, 16) }, Theme.Motion.Hover)
		self.stopDrag = Input.drag(input, fromPoint, function()
			dragging = false
			Animations.tween(thumb, { Size = UDim2.fromOffset(14, 14) }, Theme.Motion.Hover)
		end)
	end)
	self.cleanup:add(function()
		if self.stopDrag then
			self.stopDrag()
		end
	end)

	self:register("slider number")
	return self
end

function Slider:normalize(value)
	return Util.snap(tonumber(value) or self.min, self.min, self.max, self.step)
end

function Slider:stateText()
	return Util.format(self:GetValue(), self.step) .. (self.options.Suffix or "")
end

return Slider
