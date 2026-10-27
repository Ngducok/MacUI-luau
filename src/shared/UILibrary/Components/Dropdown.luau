local Core = script.Parent.Parent.Core
local Overlays = script.Parent.Parent.Overlays
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Icons = require(Core.Icons)
local Input = require(Core.Input)
local PopupManager = require(Overlays.PopupManager)
local Control = require(script.Parent.Control)

local ROW = 30
local MAX_ROWS = 8

local Dropdown = Control.extend("Dropdown")

local function label(option: any): string
	return if type(option) == "table" then option.Label or tostring(option.Value) else tostring(option)
end

local function valueOf(option: any): any
	return if type(option) == "table" then option.Value else option
end

function Dropdown.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), Dropdown)
	self.items = options.Options or {}
	self.multi = options.Multi == true

	local field = Factory.button({
		Name = "Field",
		Size = UDim2.fromOffset(options.Width or 160, 28),
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, 8, 0, 10),
	})
	self.field = field

	self.valueLabel = Factory.text({
		Size = UDim2.new(1, -20, 1, 0),
		Parent = field,
	})

	Icons.create("down", 16, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Parent = field,
	})

	self.cleanup:connect(field.MouseEnter, function()
		Theme.bind(field, { BackgroundColor3 = "SurfaceHover" })
	end)
	self.cleanup:connect(field.MouseLeave, function()
		Theme.bind(field, { BackgroundColor3 = "SurfaceActive" })
	end)

	local default = options.Default
	if self.multi then
		default = if type(default) == "table" then table.clone(default) else {}
	elseif default == nil and self.items[1] ~= nil then
		default = valueOf(self.items[1])
	end
	self:bind(default, function()
		self:_renderValue()
		if self.renderList then
			self.renderList()
		end
	end)

	self.cleanup:connect(field.Activated, function()
		if self.popup then
			self:Close()
		elseif not self.disabled then
			self:Open()
		end
	end)
	self.cleanup:add(function()
		self:Close()
	end)

	self:register("dropdown select")
	return self
end

function Dropdown:_isSelected(value: any): boolean
	local current = self:GetValue()
	if self.multi then
		return table.find(current, value) ~= nil
	end
	return current == value
end

function Dropdown:_renderValue()
	self.valueLabel.Text = self:stateText() or "Select"
	Theme.bind(self.valueLabel, { TextColor3 = if self:stateText() then "TextPrimary" else "TextMuted" })
end

function Dropdown:stateText(): string?
	local current = self:GetValue()
	if self.multi then
		if #current == 0 then
			return nil
		end
		local names = {}
		for _, item in self.items do
			if table.find(current, valueOf(item)) then
				table.insert(names, label(item))
			end
		end
		return table.concat(names, ", ")
	end
	for _, item in self.items do
		if valueOf(item) == current then
			return label(item)
		end
	end
	return if current ~= nil then tostring(current) else nil
end

function Dropdown:normalize(value)
	if self.multi then
		local out = {}
		for _, v in if type(value) == "table" then value else { value } do
			if not table.find(out, v) then
				table.insert(out, v)
			end
		end
		return out
	end
	return value
end

function Dropdown:_choose(item: any)
	local value = valueOf(item)
	if self.multi then
		local current = table.clone(self:GetValue())
		local index = table.find(current, value)
		if index then
			table.remove(current, index)
		else
			table.insert(current, value)
		end
		self:SetValue(current)
	else
		self:SetValue(value)
		self:Close()
	end
end

function Dropdown:Open()
	if self.popup then
		return
	end
	local options = self.options
	local searchable = options.Searchable == true or #self.items > 10
	local width = math.max(self.field.AbsoluteSize.X / self.ctx.popups.scale, 200)
	local surface = PopupManager.surface(width, { Name = "DropdownMenu" })
	Factory.list(0).Parent = surface

	local query
	if searchable then
		local bar = Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 38),
			BackgroundTransparency = 1,
			LayoutOrder = 1,
			Parent = surface,
		}, { Factory.padding(0, 12) })
		query = Factory.text({
			ClassName = "TextBox",
			Size = UDim2.fromScale(1, 1),
			Text = "",
			PlaceholderText = "Search options...",
			ClearTextOnFocus = false,
			TextTruncate = Enum.TextTruncate.None,
			Parent = bar,
			Theme = { PlaceholderColor3 = "TextMuted" },
		})
		Factory.new("Frame", {
			Size = UDim2.new(1, 0, 0, 1),
			LayoutOrder = 2,
			Parent = surface,
			Theme = { BackgroundColor3 = "Border" },
		})
	end

	local list = Factory.new("ScrollingFrame", {
		Size = UDim2.new(1, 0, 0, ROW),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		LayoutOrder = 3,
		Parent = surface,
		Theme = { ScrollBarImageColor3 = "Border" },
	}, {
		Factory.list(2),
		Factory.padding(6),
	})

	local rows, shown = {}, {}
	local selected = 1

	local function highlight(index: number)
		selected = index
		for i, row in rows do
			if row:IsA("TextButton") then
				Animations.tween(row, { BackgroundTransparency = if i == index then 0 else 1 }, Theme.Motion.Hover)
			end
		end
		-- Keep the highlighted row visible. Absolute values are on-screen pixels; CanvasPosition is unscaled.
		local row = rows[index]
		if row then
			local ratio = self.ctx.popups.scale
			local rowTop = (row.AbsolutePosition.Y - list.AbsolutePosition.Y) / ratio
			local rowBottom = rowTop + row.AbsoluteSize.Y / ratio
			local view = list.AbsoluteWindowSize.Y / ratio
			if rowTop < 0 then
				list.CanvasPosition -= Vector2.new(0, -rowTop + 6)
			elseif rowBottom > view then
				list.CanvasPosition += Vector2.new(0, rowBottom - view + 6)
			end
		end
	end

	local function render()
		for _, row in rows do
			row:Destroy()
		end
		table.clear(rows)
		table.clear(shown)

		local text = if query then string.lower(query.Text) else ""
		for _, item in self.items do
			if text == "" or string.find(string.lower(label(item)), text, 1, true) then
				table.insert(shown, item)
			end
		end

		for i, item in shown do
			local row = Factory.button({
				Size = UDim2.new(1, 0, 0, ROW),
				BackgroundTransparency = 1,
				LayoutOrder = i,
				Parent = list,
				Theme = { BackgroundColor3 = "PaletteSelected" },
			}, {
				Factory.corner(7),
				Factory.padding(0, 10),
			})
			Factory.text({
				Text = label(item),
				Size = UDim2.new(1, -22, 1, 0),
				Parent = row,
			})
			if self:_isSelected(valueOf(item)) then
				Icons.create({ Icon = "check", Color = "Accent" }, 16, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Parent = row,
				})
			end
			row.MouseEnter:Connect(function()
				highlight(i)
			end)
			row.Activated:Connect(function()
				self:_choose(item)
			end)
			rows[i] = row
		end

		if #shown == 0 then
			rows[1] = Factory.text({
				Text = "No matching options",
				Size = UDim2.new(1, 0, 0, ROW),
				Parent = list,
				Theme = { TextColor3 = "TextMuted" },
			}, { Factory.padding(0, 10) })
		end

		list.Size = UDim2.new(1, 0, 0, math.min(math.max(#shown, 1), MAX_ROWS) * (ROW + 2) + 10)
		highlight(math.clamp(selected, 1, math.max(#shown, 1)))
	end
	self.renderList = render

	for i, item in self.items do
		if self:_isSelected(valueOf(item)) then
			selected = i
			break
		end
	end
	render()

	local stopKeys = Input.listen(function(input)
		if input.KeyCode == Enum.KeyCode.Down then
			highlight(math.min(selected + 1, #shown))
			return true
		elseif input.KeyCode == Enum.KeyCode.Up then
			highlight(math.max(selected - 1, 1))
			return true
		elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.KeypadEnter then
			if shown[selected] then
				self:_choose(shown[selected])
			end
			if self.multi and query then
				task.defer(function()
					if query.Parent then
						query:CaptureFocus()
					end
				end)
			end
			return true
		end
		return false
	end)

	if query then
		query:GetPropertyChangedSignal("Text"):Connect(function()
			selected = 1
			render()
		end)
		task.defer(function()
			if query.Parent then
				query:CaptureFocus()
			end
		end)
	end

	self.popup = self.ctx.popups:open({
		content = surface,
		anchor = self.field,
		align = "right",
		onClose = function()
			stopKeys()
			self.popup = nil
			self.renderList = nil
		end,
	})
end

function Dropdown:Close()
	if self.popup then
		self.popup.close()
	end
end

function Dropdown:SetOptions(items: { any }, keepValue: boolean?)
	self.items = items
	if not keepValue then
		if self.multi then
			local kept = {}
			for _, value in self:GetValue() do
				for _, item in items do
					if valueOf(item) == value then
						table.insert(kept, value)
					end
				end
			end
			self:SetValue(kept)
		else
			local found = false
			for _, item in items do
				if valueOf(item) == self:GetValue() then
					found = true
				end
			end
			if not found then
				self:SetValue(if items[1] ~= nil then valueOf(items[1]) else nil)
			end
		end
	end
	self:_renderValue()
	if self.renderList then
		self.renderList()
	end
end

function Dropdown:GetOptions()
	return self.items
end

return Dropdown
