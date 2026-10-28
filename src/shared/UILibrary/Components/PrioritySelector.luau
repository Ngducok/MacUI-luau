local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Cleanup = require(Core.Cleanup)
local Icons = require(Core.Icons)
local Input = require(Core.Input)
local Util = require(Core.Util)
local Control = require(script.Parent.Control)
local PopupManager = require(script.Parent.Parent.Overlays.PopupManager)
local GuiService = game:GetService("GuiService")

local PrioritySelector = Control.extend("PrioritySelector")

export type Item = { Id: string, Label: string }
export type Options = {
	Id: string?, Title: string?, Description: string?, Items: { Item | string },
	Default: { string }?, Columns: ("Auto" | number)?,
	OnChanged: (({ string }) -> ())?, Callback: (({ string }) -> ())?,
	LayoutOrder: number?, Searchable: boolean?, Keywords: string?, Aliases: (string | { string })?,
}

local function same(a, b)
	if #a ~= #b then return false end
	for i, id in a do if b[i] ~= id then return false end end
	return true
end

local function array(value)
	assert(type(value) == "table", "Expected an array")
	for key in value do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #value, "Expected a dense array")
	end
	for i = 1, #value do assert(value[i] ~= nil, "Expected a dense array") end
end

local function itemsOf(items)
	array(items)
	local list, byId = {}, {}
	for _, item in items do
		local id = if type(item) == "string" then item else type(item) == "table" and item.Id
		local label = if type(item) == "string" then item else type(item) == "table" and item.Label
		assert(type(id) == "string" and id ~= "" and type(label) == "string", "Items need a non-empty Id and string Label")
		assert(not byId[id], `Duplicate item id "{id}"`)
		local entry = { Id = id, Label = label }
		byId[id] = entry
		table.insert(list, entry)
	end
	return list, byId
end

function PrioritySelector:_reconcile(order, strict)
	if strict then array(order) end
	local result, seen = {}, {}
	for _, id in if type(order) == "table" then order else {} do
		local valid = type(id) == "string" and self.byId[id] ~= nil and not seen[id]
		assert(not strict or valid, `Unknown or duplicate item id "{tostring(id)}"`)
		if valid then seen[id] = true; table.insert(result, id) end
	end
	for _, item in self.items do
		if not seen[item.Id] then table.insert(result, item.Id) end
	end
	return result
end

function PrioritySelector.new(ctx, parent, options: Options)
	options = table.clone(options or {})
	assert(options.Columns == nil or options.Columns == "Auto" or options.Columns == 1 or options.Columns == 2 or options.Columns == 3, "Columns must be Auto, 1, 2 or 3")
	options.Columns = options.Columns or 2
	for _, key in { "Callback", "OnChanged" } do
		assert(options[key] == nil or type(options[key]) == "function", `{key} must be a function`)
	end
	local items, byId = itemsOf(if options.Items == nil then {} else options.Items)
	local default = PrioritySelector._reconcile({ items = items, byId = byId }, if options.Default == nil then {} else options.Default, true)
	assert(options.Id == nil or (type(options.Id) == "string" and options.Id ~= ""), "Id must be a non-empty string")
	assert(not (ctx.store.defined and ctx.store.defined[options.Id]), "PrioritySelector Id already exists in this window")
	local self = setmetatable(Control.new(ctx, parent, options, true), PrioritySelector)
	self.items, self.byId, self.order = items, byId, {}
	self.itemCleanup = self.cleanup:add(Cleanup.new())
	self.pickerCleanup = self.cleanup:add(Cleanup.new())
	self.cleanup:add(function() if self.stopGesture then self.stopGesture() end end)
	self.Instance:SetAttribute("NoWindowDrag", true)
	self.widget:FindFirstChildOfClass("UIListLayout").HorizontalAlignment = Enum.HorizontalAlignment.Left
	if self.titleLabel then
		self.titleLabel.FontFace = Theme.Typography.Section.FontFace
		self.titleLabel.TextSize = Theme.Typography.Section.TextSize
	end
	self.grid = Factory.new("Frame", {
		Name = "RankChips", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
		LayoutOrder = 1, Parent = self.widget,
	})
	self.gridLayout = Factory.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(180, 38), CellPadding = UDim2.fromOffset(Theme.get("SpacingSmall"), Theme.get("SpacingSmall")),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = self.grid,
	})
	self.cleanup:connect(self.grid:GetPropertyChangedSignal("AbsoluteSize"), function() self:_fit() end)
	self.cleanup:connect(self.gridLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		local scale = self.gridLayout.AbsoluteCellSize.Y / 38
		if scale > 0 then self.grid.Size = UDim2.new(1, 0, 0, math.round(self.gridLayout.AbsoluteContentSize.Y / scale)) end
	end)
	local id, loaded = ctx.store:define(options.Id, default, function(value) return self:_reconcile(value, false) end)
	self.id, self.order = id, table.clone(loaded)
	self.cleanup:add(function() ctx.store:remove(id) end)
	self.cleanup:add(ctx.store:observe(id, function(value)
		if same(value, self.order) then return end
		self.order = table.clone(value)
		self:_render()
		if not self.silent then Util.safeCall(options.OnChanged or options.Callback, self:GetOrder()) end
	end))
	self:_buildItems()
	self:register("priority order rank")
	return self
end

function PrioritySelector:_dismiss(restoreFocus)
	if self.destroyed then return end
	self.restoreFocus = restoreFocus
	if self.popup then self.popup.close() end
end

function PrioritySelector:_select(itemId)
	if self.selectedItemId == itemId then self:_dismiss(true); return end
	self:_dismiss(false)
	self.selectedItemId = itemId
	self:_buildPicker()
	self:_render()
	self.restoreFocus = nil
	self.popup = self.ctx.popups:open({
		content = self.panel, anchor = self.chips[itemId].button, regions = { self.Instance },
		onClose = function()
			local focused = GuiService.SelectedObject
			local hadFocus = focused and (focused:IsDescendantOf(self.panel) or focused:IsDescendantOf(self.Instance))
			local restore = self.restoreFocus ~= false and hadFocus
			self.popup, self.selectedItemId = nil, nil
			self.panel, self.positions, self.positionLayout = nil, nil, nil
			self.positionButtons, self.panelTitle, self.dismissButton = nil, nil, nil
			self.pickerCleanup:clean()
			if self.stopGesture then self.stopGesture() end
			self.gestureScrolls = nil
			self:_render()
			if restore and self.chips[itemId] and self.chips[itemId].button.Parent then
				GuiService.SelectedObject = self.chips[itemId].button
			end
		end,
	})
	self.pickerCleanup:connect(self.popup.uiScale:GetPropertyChangedSignal("Scale"), function() self:_fitPicker() end)
end

function PrioritySelector:_trackPress(button, cleanup)
	(cleanup or self.itemCleanup):connect(button.InputBegan, function(input)
		if self.disabled or not Input.isPointer(input) then return end
		if self.stopGesture then self.stopGesture() end
		self.gestureBlocked = false
		self.gestureScrolls = {}
		local ancestor = button.Parent
		while ancestor do
			if ancestor:IsA("ScrollingFrame") then
				table.insert(self.gestureScrolls, { frame = ancestor, position = ancestor.CanvasPosition })
			end
			ancestor = ancestor.Parent
		end
		local origin = Input.position(input)
		self.stopGesture = Input.drag(input, function(point)
			if (point - origin).Magnitude >= 8 then self.gestureBlocked = true end
		end, function() self.stopGesture = nil end)
	end)
end

function PrioritySelector:_canActivate(input)
	if self.disabled then return false end
	if input and Input.isPointer(input) then
		if self.gestureBlocked then return false end
		for _, scroll in self.gestureScrolls or {} do
			if not scroll.frame.Parent or scroll.frame.CanvasPosition ~= scroll.position then return false end
		end
	end
	return true
end

function PrioritySelector:_buildPicker()
	local padding, gap = Theme.get("SpacingMedium"), Theme.get("SpacingSmall")
	self.panel = PopupManager.surface(220, { Name = "PriorityPositionPicker" })
	self.panel:SetAttribute("ItemId", self.selectedItemId)
	self.panel:SetAttribute("NoWindowDrag", true)
	Factory.padding(padding).Parent = self.panel
	Factory.list(gap).Parent = self.panel
	local header = Factory.new("Frame", {
		Name = "Header", Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1,
		LayoutOrder = 1, Parent = self.panel,
	})
	self.panelTitle = Factory.text({
		Text = "Move to position", Typography = "Description", Size = UDim2.new(1, -32, 1, 0), Parent = header,
		Theme = { TextColor3 = "TextSecondary" },
	})
	self.dismissButton = Factory.button({
		Name = "DismissPositionPicker", Size = UDim2.fromOffset(28, 28), Selectable = true,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = header,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, { Factory.corner(Theme.get("RadiusControl") - 1) })
	Icons.create({ Icon = "x", Color = "TextMuted" }, 12, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Parent = self.dismissButton,
	})
	self:_trackPress(self.dismissButton, self.pickerCleanup)
	self.pickerCleanup:connect(self.dismissButton.Activated, function(input)
		if self:_canActivate(input) then self:_dismiss(true) end
	end)
	self.positions = Factory.new("ScrollingFrame", {
		Name = "Positions", Size = UDim2.new(1, 0, 0, 0), BackgroundTransparency = 1,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3, ScrollingDirection = Enum.ScrollingDirection.Y,
		ClipsDescendants = true, LayoutOrder = 2, Parent = self.panel,
		Theme = { ScrollBarImageColor3 = "TextMuted" },
	})
	self.positionLayout = Factory.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(40, 30), CellPadding = UDim2.fromOffset(gap, gap),
		SortOrder = Enum.SortOrder.LayoutOrder, Parent = self.positions,
	})
	self.positionButtons = {}
	for index = 1, #self.order do
		local position = Factory.button({
			Name = `Position{index}`, LayoutOrder = index, Selectable = true, Parent = self.positions,
			BackgroundTransparency = 0, Theme = { BackgroundColor3 = "SurfaceHover" },
		}, { Factory.corner(Theme.get("RadiusControl") - 1) })
		local label = Factory.text({
			Text = string.format("%02d", index), Typography = "Hint", Size = UDim2.fromScale(1, 1),
			TextXAlignment = Enum.TextXAlignment.Center, Parent = position,
		})
		self:_trackPress(position, self.pickerCleanup)
		self.pickerCleanup:connect(position.Activated, function(input)
			if self:_canActivate(input) and self.selectedItemId then
				self:Move(self.selectedItemId, index)
				self:_dismiss(true)
			end
		end)
		self.pickerCleanup:connect(position:GetPropertyChangedSignal("GuiState"), function() self:_paintPosition(index) end)
		self.positionButtons[index] = { button = position, label = label }
	end
	self.pickerCleanup:connect(self.ctx.popups.layer:GetPropertyChangedSignal("AbsoluteSize"), function() self:_fitPicker() end)
	self:_fitPicker()
end

function PrioritySelector:_fitPicker()
	if not self.panel then return end
	local padding, gap = Theme.get("SpacingMedium"), Theme.get("SpacingSmall")
	local count, scale = #self.order, self.ctx.popups.scale
	local bounds = self.ctx.popups.layer.AbsoluteSize
	local preferred = math.max(1, if count <= 4 then count elseif count <= 10 then math.ceil(count / 2) else 5)
	local desired = math.clamp(preferred * 40 + (preferred - 1) * gap + padding * 2, 200, 260)
	local width = math.max(1, math.floor(math.min(desired, (bounds.X - 16) / scale)))
	local inner = math.max(1, width - padding * 2)
	local columns = math.min(preferred, math.max(1, math.floor((inner + gap) / (40 + gap))))
	local rows = math.ceil(count / columns)
	local available = math.max(0, (bounds.Y - 16) / scale - padding * 2 - 28 - gap)
	local height = math.min(math.min(rows, 3) * 30 + math.max(0, math.min(rows, 3) - 1) * gap, available)
	self.positions.ScrollingEnabled = height < rows * 30 + math.max(0, rows - 1) * gap
	local reserve = if self.positions.ScrollingEnabled then 6 else 0
	local cell = if count <= 4 then math.min(40, inner) else math.max(1, math.floor((inner - gap * (columns - 1) - reserve) / columns))
	self.panel.Size = UDim2.fromOffset(width, 0)
	self.positionLayout.CellSize = UDim2.fromOffset(cell, 30)
	self.positionLayout.FillDirectionMaxCells = columns
	self.positions.Size = UDim2.new(1, 0, 0, math.floor(height))
end

function PrioritySelector:_fit()
	local width = math.floor(self.grid.AbsoluteSize.X / self.ctx.scale() + 0.001)
	if width > 0 then
		local columns = if width >= 590 then 3 elseif width >= 370 then 2 else 1
		if self.columns == 3 and width >= 588 then columns = 3
		elseif self.columns == 2 and width >= 368 and width < 590 then columns = 2 end
		if type(self.options.Columns) == "number" then columns = math.min(columns, self.options.Columns) end
		self.columns = columns
		self.gridLayout.FillDirectionMaxCells = columns
		local gap = Theme.get("SpacingSmall")
		local cell = math.max(1, math.floor((width - gap * (columns - 1)) / columns))
		if self.cell ~= cell then self.cell = cell; self.gridLayout.CellSize = UDim2.fromOffset(cell, 38) end
	end
	if self.panel then self:_fitPicker() end
end

function PrioritySelector:_buildItems()
	self.itemCleanup:clean()
	self.chips = {}
	local rankWidth = math.max(22, #tostring(#self.items) * 7)
	for _, item in self.items do
		local chip = self.itemCleanup:add(Factory.button({
			Name = item.Id, Selectable = true, Parent = self.grid,
			BackgroundTransparency = 0, Theme = { BackgroundColor3 = "SurfaceHover" },
		}, { Factory.corner(Theme.get("RadiusControl") - 1), Factory.padding(0, Theme.get("SpacingMedium")) }))
		local border = Factory.stroke("Border", 0.6)
		border.Parent = chip
		local badge = Factory.new("Frame", {
			Name = "RankBadge", Size = UDim2.fromOffset(rankWidth, 22), BackgroundTransparency = 0.25,
			AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Parent = chip,
			Theme = { BackgroundColor3 = "SurfaceActive" },
		}, { Factory.corner(Theme.get("SpacingSmall")) })
		local rank = Factory.text({
			Name = "Rank", Size = UDim2.fromScale(1, 1), Typography = "Hint", Parent = badge,
			TextXAlignment = Enum.TextXAlignment.Center, Theme = { TextColor3 = "TextMuted" },
		})
		Factory.text({
			Text = item.Label, Typography = "Control", Position = UDim2.fromOffset(rankWidth + 8, 0),
			Size = UDim2.new(1, -rankWidth - 28, 1, 0), Parent = chip,
		})
		local chevron = Icons.create({ Icon = "chevron-small-down", Color = "TextMuted" }, 12, {
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.fromScale(1, 0.5), Parent = chip,
		})
		self:_trackPress(chip)
		self.itemCleanup:connect(chip.Activated, function(input)
			if self:_canActivate(input) then self:_select(item.Id) end
		end)
		self.itemCleanup:connect(chip:GetPropertyChangedSignal("GuiState"), function() self:_paintChip(item.Id) end)
		self.chips[item.Id] = { button = chip, rank = rank, border = border, chevron = chevron }
	end
	self:_fit()
	self:_render()
	if self.disabled then Control.SetDisabled(self, true) end
end

function PrioritySelector:_paintChip(id)
	local chip = self.chips[id]
	local selected = id == self.selectedItemId
	local state = chip.button.GuiState
	local color = if selected then "SurfaceActive" else "SurfaceHover"
	if not self.disabled then
		if state == Enum.GuiState.Press then color = "PaletteSelected"
		elseif state == Enum.GuiState.Hover then color = "SurfaceActive" end
	end
	Theme.bind(chip.button, { BackgroundColor3 = color })
	Theme.bind(chip.rank, { TextColor3 = if selected then "Accent" else "TextMuted" })
	chip.border.Transparency = if selected then 0.4 else 0.6
	chip.chevron.Rotation = if selected then 180 else 0
end

function PrioritySelector:_paintPosition(index)
	local position = self.positionButtons[index]
	local current = self.selectedItemId and self.order[index] == self.selectedItemId
	local state = position.button.GuiState
	local color = if current then "SurfaceActive" else "SurfaceHover"
	if not self.disabled then
		if state == Enum.GuiState.Press then color = "PaletteSelected"
		elseif state == Enum.GuiState.Hover then color = "SurfaceActive" end
	end
	Theme.bind(position.button, { BackgroundColor3 = color })
	Theme.bind(position.label, { TextColor3 = if current then "Accent" else "TextPrimary" })
end

function PrioritySelector:_render()
	self:_fit()
	for index, id in self.order do
		local chip = self.chips and self.chips[id]
		if chip then
			chip.button.LayoutOrder = index
			chip.rank.Text = string.format("%02d", index)
			self:_paintChip(id)
		end
	end
	for index in self.positionButtons or {} do self:_paintPosition(index) end
end

function PrioritySelector:GetOrder(): { string }
	return table.clone(self.order)
end

function PrioritySelector:SetOrder(order: { string }, options: { Silent: boolean }?)
	assert(options == nil or (type(options) == "table" and (options.Silent == nil or type(options.Silent) == "boolean")), "SetOrder options need a boolean Silent")
	local nextOrder = self:_reconcile(order, true)
	if same(nextOrder, self.order) then return end
	self.silent = options and options.Silent == true
	self.ctx.store:set(self.id, nextOrder)
	self.silent = false
end

function PrioritySelector:Move(itemId: string, targetIndex: number)
	assert(self.byId[itemId], "Unknown item Id")
	assert(type(targetIndex) == "number" and targetIndex % 1 == 0 and targetIndex >= 1 and targetIndex <= #self.order, "Target position is out of range")
	local order = self:GetOrder()
	local from = table.find(order, itemId)
	if from == targetIndex then return end
	table.remove(order, from)
	table.insert(order, targetIndex, itemId)
	self:SetOrder(order)
end

function PrioritySelector:SetItems(items: { Item | string })
	local list, byId = itemsOf(items)
	local selected = self.selectedItemId
	self:_dismiss(false)
	self.items, self.byId = list, byId
	local order = self:_reconcile(self.order, false)
	self:_buildItems()
	self:SetOrder(order)
	if selected and byId[selected] and not self.destroyed then self:_select(selected) end
end

function PrioritySelector:SetVisible(visible)
	if not visible then self:_dismiss(false) end
	Control.SetVisible(self, visible)
end

function PrioritySelector:SetDisabled(disabled)
	if disabled then self:_dismiss(false) end
	Control.SetDisabled(self, disabled)
	self:_render()
end

function PrioritySelector:Destroy()
	if self.destroyed then return end
	self:_dismiss(false)
	Control.Destroy(self)
end

function PrioritySelector:stateText(): string
	local labels = {}
	for _, id in self.order do if self.byId[id] then table.insert(labels, self.byId[id].Label) end end
	return table.concat(labels, ", ")
end

PrioritySelector.GetValue = PrioritySelector.GetOrder
PrioritySelector.SetValue = PrioritySelector.SetOrder

return PrioritySelector
