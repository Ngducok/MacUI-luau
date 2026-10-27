local Core = script.Parent.Parent.Core
local Factory = require(Core.Factory)
local Icons = require(Core.Icons)
local Theme = require(Core.Theme)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Input = require(Core.Input)

local SIZE, MARGIN = 48, 12
local MobileLauncher = {}
MobileLauncher.__index = MobileLauncher

function MobileLauncher.new(window)
	local self = setmetatable({ window = window, cleanup = Cleanup.new() }, MobileLauncher)
	self.gui = self.cleanup:add(Factory.new("ScreenGui", {
		Name = "MacUILauncher", ResetOnSpawn = false,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = window.gui.DisplayOrder + 3, Parent = window.gui.Parent,
	}))
	self.area = Factory.new("Frame", { Name = "SafeArea", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Parent = self.gui })
	self.root = Factory.new("Frame", { Name = "Launcher", Size = UDim2.fromOffset(SIZE, SIZE),
		BackgroundTransparency = 1, Parent = self.area })
	for _, spread in { 4, 8 } do
		Factory.new("Frame", { Name = "Shadow", AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 3), Size = UDim2.fromOffset(SIZE + spread, SIZE + spread),
			BackgroundTransparency = 0.94, Interactable = false, Parent = self.root,
			Theme = { BackgroundColor3 = "Shadow" },
		}, { Factory.new("UICorner", { CornerRadius = UDim.new(1, 0) }) })
	end
	local button = Factory.button({ Name = "ToggleMacUI", Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 0.08, ZIndex = 2, Parent = self.root,
		Theme = { BackgroundColor3 = "Palette" },
	}, { Factory.new("UICorner", { CornerRadius = UDim.new(1, 0) }), Factory.stroke("PaletteBorder", 0.2) })
	self.button = button
	self.icon = Icons.create({ Icon = "sidebar", Color = "TextPrimary" }, 22, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = button,
	})
	self.cleanup:connect(button.InputBegan, function(input)
		if self.stopDrag or not Input.isPointer(input) then return end
		self.pointer, self.suppressActivation = input, false
		local origin = Input.position(input)
		local position = Vector2.new(self.root.Position.X.Offset, self.root.Position.Y.Offset)
		self.stopDrag = Input.drag(input, function(point)
			local delta = point - origin
			if not self.suppressActivation and delta.Magnitude < 8 then return end
			self.suppressActivation = true
			self:_move(position + delta)
		end, function()
			if input.UserInputState ~= Enum.UserInputState.End then self.suppressActivation = true end
			self.stopDrag = nil
		end)
	end)
	self.cleanup:connect(button.Activated, function(input)
		if input and input.UserInputType == Enum.UserInputType.Touch and input ~= self.pointer then return end
		if self.suppressActivation and (not input or Input.isPointer(input)) then return end
		window:Toggle()
	end)
	self.cleanup:add(function() if self.stopDrag then self.stopDrag() end end)
	self.cleanup:connect(button:GetPropertyChangedSignal("GuiState"), function()
		Theme.bind(button, { BackgroundColor3 = if button.GuiState == Enum.GuiState.Press then "SurfaceActive"
			elseif button.GuiState == Enum.GuiState.Hover then "SurfaceHover" else "Palette" })
		Animations.tween(button, { BackgroundTransparency = if button.GuiState == Enum.GuiState.Idle then 0.08 else 0 }, Theme.Motion.Hover)
	end)
	local function viewportChanged()
		if self.stopDrag then self.stopDrag() end
		self:_place()
	end
	self.cleanup:connect(self.area:GetPropertyChangedSignal("AbsoluteSize"), viewportChanged)
	self.cleanup:connect(self.area:GetPropertyChangedSignal("AbsolutePosition"), viewportChanged)
	self.cleanup:connect(window.root:GetPropertyChangedSignal("AbsoluteSize"), function() self:_place() end)
	self:_place()
	self:refresh()
	return self
end

function MobileLauncher:_move(position: Vector2)
	local size = self.area.AbsoluteSize
	local x = math.round(math.clamp(position.X, 0, math.max(0, size.X - SIZE)))
	local y = math.round(math.clamp(position.Y, 0, math.max(0, size.Y - SIZE)))
	self.offset = Vector2.new(x, y)
	self.root.Position = UDim2.fromOffset(x, y)
end

function MobileLauncher:_place()
	local area, window = self.area, self.window
	local size = area.AbsoluteSize
	if size.X < SIZE or size.Y < SIZE then return end
	if self.offset then self:_move(self.offset) return end
	local marginX, marginY = math.min(MARGIN, (size.X - SIZE) / 2), math.min(MARGIN, (size.Y - SIZE) / 2)
	local left, right = marginX, size.X - SIZE - marginX
	local preferred = if window.options.MobileTogglePosition == "Left" then left else right
	local other = if preferred == left then right else left
	local pos, bounds = window.root.AbsolutePosition - area.AbsolutePosition, window.root.AbsoluteSize
	local selected
	for _, fraction in { 0.5, 0.25, 0.75 } do
		local y = math.clamp(math.round(size.Y * fraction - SIZE / 2), marginY, size.Y - SIZE - marginY)
		for _, x in { preferred, other } do
			local candidate = Vector2.new(math.round(x), math.round(y))
			selected = selected or candidate
			if x + SIZE <= pos.X or x >= pos.X + bounds.X or y + SIZE <= pos.Y or y >= pos.Y + bounds.Y then
				self.root.Position = UDim2.fromOffset(candidate.X, candidate.Y)
				return
			end
		end
	end
	-- If the window fills the viewport, the higher DisplayOrder keeps the launcher reachable.
	self.root.Position = UDim2.fromOffset(selected.X, selected.Y)
end

function MobileLauncher:refresh()
	self.button:SetAttribute("WindowVisible", self.window.visible)
	Icons.tint(self.icon, if self.window.visible then "TextPrimary" else "TextSecondary")
end

function MobileLauncher:Destroy()
	self.cleanup:clean()
end

return MobileLauncher
