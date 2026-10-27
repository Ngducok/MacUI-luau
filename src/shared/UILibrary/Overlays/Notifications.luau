local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Cleanup = require(Core.Cleanup)
local Util = require(Core.Util)

local WIDTH = 320
local MAX_VISIBLE = 4

local KINDS = {
	info = { "circle-i", "Accent" },
	success = { "circle-check", "Success" },
	warning = { "triangle-exclamation", "Warning" },
	error = { "circle-x", "Danger" },
}

local Notifications = {}
Notifications.__index = Notifications

export type Options = {
	Title: string,
	Content: string?,
	Duration: number?,
	Kind: ("info" | "success" | "warning" | "error")?,
	Actions: { { Text: string, Callback: (() -> ())? } }?,
}

function Notifications.new(gui: ScreenGui)
	local self = setmetatable({ cleanup = Cleanup.new(), active = {} }, Notifications)
	self.holder = self.cleanup:add(Factory.new("Frame", {
		Name = "Notifications",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 100,
		Parent = gui,
	}, {
		Factory.list(8, false, { VerticalAlignment = Enum.VerticalAlignment.Bottom }),
	}))
	self.uiScale = Factory.new("UIScale", { Parent = self.holder })
	return self
end

function Notifications:setScale(scale: number)
	self.uiScale.Scale = scale
end

function Notifications:notify(options: Options)
	local kind = KINDS[string.lower(options.Kind or "info")] or KINDS.info
	local order = (self.counter or 0) + 1
	self.counter = order

	local slot = Factory.new("Frame", {
		Name = "ToastRoot",
		Size = UDim2.new(1, 0, 0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		LayoutOrder = order,
		Parent = self.holder,
	})

	local card = Factory.new("Frame", {
		Name = "Surface",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(WIDTH + 24, 0),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = slot,
		Theme = { BackgroundColor3 = "Palette" },
	}, {
		Factory.corner(12),
		Factory.new("UIStroke", {
			ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
			BorderStrokePosition = Enum.BorderStrokePosition.Inner,
			Thickness = 1,
			Theme = { Color = "PaletteBorder" },
		}),
		Factory.padding(12, 14),
	})

	Icons.create({ Icon = kind[1], Color = kind[2] }, 18, { Position = UDim2.fromOffset(0, 1), Parent = card })
	local text = Factory.new("Frame", {
		Position = UDim2.fromOffset(28, 0),
		Size = UDim2.new(1, -52, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = card,
	}, { Factory.list(3) })
	Factory.text({
		Text = options.Title,
		Typography = "Section",
		Size = UDim2.new(1, 0, 0, 18),
		Parent = text,
	})
	if options.Content then
		Factory.text({
			Text = options.Content,
			Typography = "Description",
			TextWrapped = true,
			TextTruncate = Enum.TextTruncate.None,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextSecondary" },
		})
	end

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local index = table.find(self.active, close)
		if index then
			table.remove(self.active, index)
		end
		local height = math.round(slot.AbsoluteSize.Y / math.max(self.uiScale.Scale, 0.01))
		slot.AutomaticSize = Enum.AutomaticSize.None
		slot.Size = UDim2.new(1, 0, 0, height)
		Animations.tween(card, { Position = UDim2.fromOffset(WIDTH + 24, 0) }, Theme.Motion.Notify, Enum.EasingStyle.Quad)
		local tween = Animations.tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, Theme.Motion.Notify)
		if tween then
			tween.Completed:Once(function()
				slot:Destroy()
			end)
		else
			slot:Destroy()
		end
	end

	if options.Actions then
		local row = Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			LayoutOrder = 3,
			Parent = text,
		}, { Factory.list(6, true), Factory.padding(6, 0, 0, 0) })
		row.AutomaticSize = Enum.AutomaticSize.Y
		for i, action in options.Actions do
			local button = require(script.Parent.Parent.Components.Button).make({
				Text = action.Text,
				Variant = if i == 1 then "Primary" else "Secondary",
				Height = 24,
				LayoutOrder = i,
			})
			button.Parent = row
			button.Activated:Connect(function()
				Util.safeCall(action.Callback)
				close()
			end)
		end
	end

	local closeButton = Factory.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(18, 18),
		Parent = card,
	})
	Icons.create({ Icon = "x", Color = "TextMuted" }, 14, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = closeButton,
	})
	closeButton.Activated:Connect(close)

	task.defer(function()
		if closed then
			return
		end
		local height = math.round(card.AbsoluteSize.Y / math.max(self.uiScale.Scale, 0.01))
		local tween = Animations.tween(slot, { Size = UDim2.new(1, 0, 0, height) }, Theme.Motion.Notify)
		Animations.tween(card, { Position = UDim2.fromOffset(0, 0) }, Theme.Motion.Notify, Enum.EasingStyle.Quint)
		local function fit()
			if not closed then
				slot.AutomaticSize = Enum.AutomaticSize.Y
				slot.Size = UDim2.new(1, 0, 0, 0)
			end
		end
		if tween then
			tween.Completed:Once(fit)
		else
			fit()
		end
	end)

	table.insert(self.active, close)
	while #self.active > MAX_VISIBLE do
		self.active[1]()
	end

	local duration = options.Duration or 4
	if duration > 0 then
		task.delay(duration, close)
	end
	return close
end

function Notifications:count(): number
	return #self.active
end

function Notifications:Destroy()
	self.cleanup:clean()
end

return Notifications
