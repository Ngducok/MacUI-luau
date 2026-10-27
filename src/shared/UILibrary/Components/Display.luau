local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)
local AnimatedImage = require(script.Parent.AnimatedImage)

local Display = {}

local BADGE_TOKENS = {
	Neutral = { "SurfaceActive", "TextSecondary" },
	Success = { "Success", "Success" },
	Warning = { "Warning", "Warning" },
	Danger = { "Danger", "Danger" },
	Accent = { "Accent", "Accent" },
}

function Display.badge(text: string, kind: string?): Frame
	local tokens = BADGE_TOKENS[kind or "Neutral"] or BADGE_TOKENS.Neutral
	local tinted = kind ~= nil and kind ~= "Neutral"
	local badge = Factory.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = if tinted then 0.84 else 0,
		Theme = { BackgroundColor3 = tokens[1] },
	}, {
		Factory.corner(6),
		Factory.padding(0, 7),
	})
	Factory.text({
		Name = "Label",
		Text = text,
		Typography = "Hint",
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		Parent = badge,
		Theme = { TextColor3 = tokens[2] },
	})
	return badge
end

-- Label: title + optional value on the right.
local Label = Control.extend("Label")
Display.Label = Label

function Label.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Label)
	self.valueLabel = Factory.text({
		Text = options.Value or "",
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextTruncate = Enum.TextTruncate.None,
		Visible = options.Value ~= nil,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})
	return self
end

function Label:SetValue(value: any)
	self.valueLabel.Text = tostring(value)
	self.valueLabel.Visible = value ~= nil
end

function Label:GetValue()
	return self.valueLabel.Text
end

-- Paragraph: wrapped body copy.
local Paragraph = Control.extend("Paragraph")
Display.Paragraph = Paragraph

function Paragraph.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, {
		Title = options.Title,
		LayoutOrder = options.LayoutOrder,
		Description = options.Content or options.Text or "",
	}, true), Paragraph)
	self.options = options
	self.widget.Visible = false
	return self
end

function Paragraph:SetValue(text: string)
	self:SetDescription(text)
end

function Paragraph:GetValue()
	return self.options.Description or self.options.Content or self.options.Text
end

-- Divider
local Divider = Control.extend("Divider")
Display.Divider = Divider

function Divider.new(_ctx, parent, options)
	local self = setmetatable({ options = options, visible = true, cleanup = require(Core.Cleanup).new() }, Divider)
	self.Instance = self.cleanup:add(Factory.new("Frame", {
		Name = "Divider",
		Size = UDim2.new(1, 0, 0, 1),
		LayoutOrder = options.LayoutOrder or 0,
		Parent = parent,
		Theme = { BackgroundColor3 = "Border" },
	}))
	self.Instance.BackgroundTransparency = 0.4
	return self
end

function Divider:GetValue()
	return nil
end

-- Status badge row
local Status = Control.extend("Status")
Display.Status = Status

function Status.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Status)
	self:SetValue(options.Value or "Idle", options.Kind)
	return self
end

function Status:SetValue(text: string, kind: string?)
	if self.badge then
		self.badge:Destroy()
	end
	self.text, self.kind = text, kind or self.kind
	self.badge = Display.badge(text, self.kind)
	self.badge.Parent = self.widget
end

function Status:GetValue()
	return self.text
end

function Status:stateText()
	return self.text
end

-- Progress bar: Value 0..1 or nil for an indeterminate shimmer.
local Progress = Control.extend("Progress")
Display.Progress = Progress

function Progress.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Progress)

	self.percent = Factory.text({
		Size = UDim2.fromOffset(40, 18),
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})
	local rail = Factory.new("Frame", {
		Size = UDim2.fromOffset(options.Width or 150, 4),
		LayoutOrder = 2,
		ClipsDescendants = true,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(2) })
	self.fill = Factory.new("Frame", {
		Size = UDim2.fromScale(0, 1),
		Parent = rail,
		Theme = { BackgroundColor3 = options.Color or "Accent" },
	}, { Factory.corner(2) })
	self:SetValue(options.Value)
	return self
end

function Progress:SetValue(value: number?)
	if self.stopShimmer then
		self.stopShimmer()
		self.stopShimmer = nil
	end
	self.value = value
	if value == nil then
		self.percent.Text = ""
		self.fill.Size = UDim2.fromScale(0.3, 1)
		self.fill.Position = UDim2.fromScale(-0.3, 0)
		local tween = game:GetService("TweenService"):Create(
			self.fill,
			TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1),
			{ Position = UDim2.fromScale(1, 0) }
		)
		if not Animations.reducedMotion then
			tween:Play()
		end
		self.stopShimmer = function()
			tween:Cancel()
			self.fill.Position = UDim2.new()
		end
		self.cleanup:add(self.stopShimmer)
		return
	end
	local alpha = math.clamp(value, 0, 1)
	self.percent.Text = `{math.round(alpha * 100)}%`
	self.fill.Position = UDim2.new()
	Animations.tween(self.fill, { Size = UDim2.fromScale(alpha, 1) }, Theme.Motion.Toggle)
end

function Progress:GetValue()
	return self.value
end

function Progress:stateText()
	return if self.value then `{math.round(self.value * 100)}%` else nil
end

-- Image preview or animated sprite sheet.
local Image = Control.extend("Image")
Display.Image = Image

function Image.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options, true), Image)
	local height = options.Height or 140

	local frame = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		ClipsDescendants = true,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "Background" },
	}, { Factory.corner(10) })

	if options.Columns and options.Frames then
		self.animation = AnimatedImage.new({
			Image = options.Image,
			FrameSize = options.FrameSize,
			Columns = options.Columns,
			Frames = options.Frames,
			FPS = options.FPS,
			Loop = options.Loop,
			Autoplay = options.Autoplay,
			Speed = options.Speed,
			Size = UDim2.fromScale(1, 1),
		})
		self.animation.Instance.Parent = frame
		self.cleanup:add(self.animation)
	else
		Factory.new("ImageLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Image = options.Image or "",
			ScaleType = options.ScaleType or Enum.ScaleType.Fit,
			Parent = frame,
		})
	end
	return self
end

function Image:Play()
	if self.animation then
		self.animation:Play()
	end
end

function Image:Pause()
	if self.animation then
		self.animation:Pause()
	end
end

function Image:GetValue()
	return self.options.Image
end

-- Tooltip: hover a GuiObject to show text in the overlay layer.
function Display.tooltip(popups, target: GuiObject, text: string): () -> ()
	local open
	local token = 0
	local enter = target.MouseEnter:Connect(function()
		token += 1
		local mine = token
		task.delay(0.45, function()
			if mine ~= token or open or not target:IsDescendantOf(game) then
				return
			end
			local tip = Factory.new("Frame", {
				Size = UDim2.fromOffset(0, 24),
				AutomaticSize = Enum.AutomaticSize.X,
				Theme = { BackgroundColor3 = "SurfaceActive" },
			}, {
				Factory.corner(6),
				Factory.stroke("PaletteBorder"),
				Factory.padding(0, 8),
				Factory.new("UISizeConstraint", { MaxSize = Vector2.new(260, 24) }),
			})
			Factory.text({
				Text = text,
				Typography = "Hint",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				Parent = tip,
			})
			open = popups:open({
				content = tip,
				anchor = target,
				gap = 6,
				onClose = function()
					open = nil
				end,
			})
		end)
	end)
	local leave = target.MouseLeave:Connect(function()
		token += 1
		if open then
			open.close()
		end
	end)
	return function()
		enter:Disconnect()
		leave:Disconnect()
		if open then
			open.close()
		end
	end
end

-- Icon button used in headers.
function Display.iconButton(icon: any, size: number?, callback: (() -> ())?): TextButton
	local box = size or 26
	local button = Factory.button({
		Name = if type(icon) == "string" then icon else "IconButton",
		Size = UDim2.fromOffset(box, box),
		BackgroundTransparency = 1,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, { Factory.corner(7) })
	local glyph = Icons.create(icon, math.round(box * 0.62), {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = button,
	})
	button.MouseEnter:Connect(function()
		Animations.tween(button, { BackgroundTransparency = 0 }, Theme.Motion.Hover)
		if type(icon) == "string" then
			Icons.tint(glyph, "TextPrimary")
		end
	end)
	button.MouseLeave:Connect(function()
		Animations.tween(button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		if type(icon) == "string" then
			Icons.tint(glyph, "TextSecondary")
		end
	end)
	if callback then
		button.Activated:Connect(function()
			Util.safeCall(callback)
		end)
	end
	return button
end

return Display
