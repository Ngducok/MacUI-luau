local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Input = require(Core.Input)
local Cleanup = require(Core.Cleanup)

local MARGIN = 8

local PopupManager = {}
PopupManager.__index = PopupManager

export type Policy = {
	OpenOn: "Click"?,
	CloseOnOutsideClick: boolean?,
	CloseOnEscape: boolean?,
	CloseOnMouseLeave: false?,
	CloseOnInteraction: false?,
}

export type Options = {
	content: GuiObject,
	anchor: GuiObject?,
	within: GuiObject?,
	align: "left" | "right" | nil,
	placement: "below" | "center" | nil,
	gap: number?,
	modal: boolean?,
	dismissible: boolean?,
	onClose: (() -> ())?,
	layer: GuiObject?,
	backdrop: GuiObject?,
	scale: number?,
	place: ((any) -> ())?,
	onClosing: ((() -> ()) -> ())?,
	owner: any?,
	group: string?,
	regions: { GuiObject }?,
	policy: Policy?,
}

function PopupManager.new(gui: ScreenGui)
	local self = setmetatable({
		stack = {},
		closing = {},
		scale = 1,
		cleanup = Cleanup.new(),
	}, PopupManager)

	self.layer = self.cleanup:add(Factory.new("Frame", {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 50,
		Parent = gui,
	}))

	self.cleanup:add(Input.listen(function(input)
		return self:_input(input)
	end))
	return self
end

function PopupManager:_input(input: InputObject): boolean
	local top = self.stack[#self.stack]
	if not top then
		return false
	end

	if input.KeyCode == Enum.KeyCode.Escape then
		if top.closeOnEscape then
			top.close()
		end
		return true
	end

	if Input.isPointer(input) then
		local point = Input.position(input)
		-- Use the stack at InputBegan; callbacks may open/close overlays during this input.
		local stack = table.clone(self.stack)
		for i = #stack, 1, -1 do
			local popup = stack[i]
			if not popup.open then continue end
			local inside = Input.inside(popup.frame, point) or (popup.anchor and Input.inside(popup.anchor, point))
			for _, region in popup.regions do
				inside = inside or (region.Parent ~= nil and Input.inside(region, point))
			end
			if inside or not popup.closeOnOutsideClick then
				break
			end
			popup.close()
			if popup.modal then break end
		end
	end
	return false
end

function PopupManager:_place(popup)
	local frame, layer = popup.frame, self.layer
	local size = frame.AbsoluteSize
	local bounds = layer.AbsoluteSize
	local x, y

	if popup.placement == "center" then
		local within = popup.within or layer
		local pos, area = within.AbsolutePosition, within.AbsoluteSize
		x = pos.X + (area.X - size.X) / 2
		y = pos.Y + math.min(area.Y * 0.16, math.max(area.Y - size.Y, 0) / 2)
	elseif popup.anchor then
		local pos, area = popup.anchor.AbsolutePosition, popup.anchor.AbsoluteSize
		local gap = (popup.gap or 6) * self.scale
		x = if popup.align == "right" then pos.X + area.X - size.X else pos.X
		y = pos.Y + area.Y + gap
		if y + size.Y > bounds.Y - MARGIN and pos.Y - gap - size.Y >= MARGIN then
			y = pos.Y - gap - size.Y
		end
	else
		x, y = (bounds.X - size.X) / 2, (bounds.Y - size.Y) / 2
	end

	x = math.clamp(x, MARGIN, math.max(MARGIN, bounds.X - size.X - MARGIN))
	y = math.clamp(y, MARGIN, math.max(MARGIN, bounds.Y - size.Y - MARGIN))
	frame.Position = UDim2.fromOffset(math.round(x), math.round(y))
end

function PopupManager:open(options: Options)
	local policy = options.policy or {}
	-- ponytail: feature popovers are click-only; hover/interaction dismissal needs a separate policy.
	assert(policy.OpenOn == nil or policy.OpenOn == "Click", "Popover.OpenOn must be Click")
	assert(policy.CloseOnMouseLeave == nil or policy.CloseOnMouseLeave == false, "Popovers stay open on mouse leave")
	assert(policy.CloseOnInteraction == nil or policy.CloseOnInteraction == false, "Popovers stay open during interaction")
	for _, key in { "CloseOnOutsideClick", "CloseOnEscape" } do
		assert(policy[key] == nil or type(policy[key]) == "boolean", `Popover.{key} must be a boolean`)
	end
	local owner = options.owner
	if not owner and options.anchor then
		for i = #self.stack, 1, -1 do
			if options.anchor:IsDescendantOf(self.stack[i].frame) then
				owner = self.stack[i]
				break
			end
		end
	end
	if options.group then
		for _, existing in table.clone(self.stack) do
			if existing.group == options.group then existing.close() end
		end
	end
	local cleanup = Cleanup.new()
	local frame = options.content
	local popup = {
		frame = frame,
		anchor = options.anchor,
		within = options.within,
		align = options.align,
		placement = options.placement,
		gap = options.gap,
		modal = options.modal == true,
		dismissible = options.dismissible ~= false,
		closeOnOutsideClick = options.dismissible ~= false and policy.CloseOnOutsideClick ~= false,
		closeOnEscape = options.dismissible ~= false and policy.CloseOnEscape ~= false,
		owner = owner,
		group = options.group,
		regions = options.regions or {},
		open = true,
	}

	local layer = options.layer or self.layer
	local parent = layer
	if popup.modal then
		local scrim = cleanup:add(Factory.button({
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 1,
			Parent = layer,
			Theme = { BackgroundColor3 = "Scrim" },
		}))
		Animations.tween(options.backdrop or scrim, { BackgroundTransparency = 0.55 }, Theme.Motion.Popup)
		-- Dismiss only on InputBegan through the manager, never on a drag's release.
		parent = scrim
	end

	local scale = options.scale or self.scale
	local uiScale = Factory.new("UIScale", { Scale = if options.scale then scale else scale * 0.97, Parent = frame })
	popup.uiScale = uiScale
	popup.fixedScale = options.scale ~= nil
	frame.AnchorPoint = Vector2.zero
	frame.ZIndex = 2
	frame.Parent = parent
	cleanup:add(frame)

	local function place()
		if popup.open then
			if options.place then
				options.place(popup)
			else
				self:_place(popup)
			end
		end
	end
	cleanup:connect(frame:GetPropertyChangedSignal("AbsoluteSize"), place)
	cleanup:connect(layer:GetPropertyChangedSignal("AbsoluteSize"), place)
	if popup.anchor then
		cleanup:connect(popup.anchor:GetPropertyChangedSignal("AbsolutePosition"), place)
	end
	place()
	if not popup.fixedScale then
		Animations.tween(uiScale, { Scale = scale }, Theme.Motion.Popup)
	end

	function popup.close()
		if not popup.open then
			return
		end
		popup.open = false
		for _, child in table.clone(self.stack) do
			if child.owner == popup then child.close() end
		end
		local index = table.find(self.stack, popup)
		if index then
			table.remove(self.stack, index)
		end
		if options.onClose then
			options.onClose()
		end
		local function finish()
			self.closing[popup] = nil
			cleanup:clean()
		end
		if options.onClosing then
			self.closing[popup] = finish
			options.onClosing(finish)
		else
			finish()
		end
	end

	table.insert(self.stack, popup)
	if popup.anchor then
		local function checkAnchor()
			local node = popup.anchor
			while node do
				if (node:IsA("GuiObject") and not node.Visible) or (node:IsA("ScreenGui") and not node.Enabled) then
					popup.close()
					return
				end
				node = node.Parent
			end
			if not popup.anchor:IsDescendantOf(game) then popup.close() end
		end
		cleanup:connect(popup.anchor.AncestryChanged, checkAnchor)
		local node = popup.anchor
		while node do
			if node:IsA("GuiObject") then
				cleanup:connect(node:GetPropertyChangedSignal("Visible"), checkAnchor)
			elseif node:IsA("ScreenGui") then
				cleanup:connect(node:GetPropertyChangedSignal("Enabled"), checkAnchor)
			end
			node = node.Parent
		end
	end
	return popup
end

function PopupManager:setScale(scale: number)
	self.scale = scale
	for _, popup in self.stack do
		if not popup.fixedScale then
			Animations.tween(popup.uiScale, { Scale = scale })
		end
	end
end

function PopupManager:closeAll()
	for i = #self.stack, 1, -1 do
		local popup = self.stack[i]
		if popup then popup.close() end
	end
end

function PopupManager:isOpen(): boolean
	return #self.stack > 0
end

-- A floating surface with the palette styling, used by dropdowns, inspectors and dialogs.
function PopupManager.surface(width: number, props: { [string]: any }?): Frame
	local frame = Factory.new("Frame", {
		Size = UDim2.fromOffset(width, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Active = true,
		Theme = { BackgroundColor3 = "Palette" },
	}, {
		Factory.corner(12),
		Factory.stroke("PaletteBorder"),
	})
	for key, value in props or {} do
		frame[key] = value
	end
	return frame
end

function PopupManager:Destroy()
	self:closeAll()
	for _, finish in table.clone(self.closing) do
		finish()
	end
	self.cleanup:clean()
end

return PopupManager
