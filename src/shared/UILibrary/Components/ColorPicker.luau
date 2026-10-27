local Core = script.Parent.Parent.Core
local Overlays = script.Parent.Parent.Overlays
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Input = require(Core.Input)
local Util = require(Core.Util)
local PopupManager = require(Overlays.PopupManager)
local Control = require(script.Parent.Control)

local WIDTH = 240
local MAX_RECENT = 8

local recent: { Color3 } = {}

local ColorPicker = Control.extend("ColorPicker")

local function remember(color: Color3)
	for i = #recent, 1, -1 do
		if recent[i]:ToHex() == color:ToHex() then
			table.remove(recent, i)
		end
	end
	table.insert(recent, 1, color)
	recent[MAX_RECENT + 1] = nil
end

local function bar(height: number, order: number, parent: Instance)
	return Factory.button({
		Size = UDim2.new(1, 0, 0, height),
		BackgroundTransparency = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		LayoutOrder = order,
		Parent = parent,
	}, { Factory.corner(height // 2) })
end

local function cursor(parent: Instance, size: number)
	return Factory.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundTransparency = 1,
		ZIndex = 3,
		Parent = parent,
	}, {
		Factory.corner(size // 2),
		Factory.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2 }),
	})
end

local function field(width: number, order: number, parent: Instance)
	local box = Factory.new("Frame", {
		Size = UDim2.fromOffset(width, 26),
		LayoutOrder = order,
		Parent = parent,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(7), Factory.padding(0, 8) })
	return Factory.text({
		ClassName = "TextBox",
		Size = UDim2.fromScale(1, 1),
		ClearTextOnFocus = false,
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None,
		Parent = box,
	})
end

function ColorPicker.new(ctx, parent, options)
	local self = setmetatable(Control.new(ctx, parent, options), ColorPicker)
	self.hasAlpha = options.Transparency ~= nil

	local swatch = Factory.button({
		Name = "Swatch",
		Size = UDim2.fromOffset(44, 24),
		BackgroundTransparency = 0,
		LayoutOrder = 2,
		Parent = self.widget,
	}, { Factory.corner(7), Factory.stroke("Border") })
	self.swatch = swatch

	self.hexLabel = Factory.text({
		Size = UDim2.fromOffset(62, 24),
		Typography = "Description",
		TextXAlignment = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Parent = self.widget,
		Theme = { TextColor3 = "TextSecondary" },
	})

	local store = ctx.store
	if self.hasAlpha then
		self.alphaId = store:define(if options.Id then `{options.Id}.transparency` else nil, math.clamp(options.Transparency, 0, 1))
		self.cleanup:add(store:observe(self.alphaId, function(alpha)
			swatch.BackgroundTransparency = alpha
			Util.safeCall(options.Callback, self:GetValue(), alpha)
			if self.renderInspector then
				self.renderInspector()
			end
		end))
		swatch.BackgroundTransparency = store:get(self.alphaId)
		self.cleanup:add(function()
			store:remove(self.alphaId)
		end)
	end

	local callback = options.Callback
	self.options = Util.merge(options, {
		Callback = function(color)
			if callback then
				callback(color, self:GetTransparency())
			end
		end,
	})
	self:bind(options.Default or Color3.new(1, 1, 1), function(color)
		swatch.BackgroundColor3 = color
		self.hexLabel.Text = "#" .. string.upper(color:ToHex())
		if self.renderInspector then
			self.renderInspector()
		end
	end)

	self.cleanup:connect(swatch.Activated, function()
		if self.popup then
			self:Close()
		elseif not self.disabled then
			self:Open()
		end
	end)
	self.cleanup:add(function()
		self:Close()
	end)

	self:register("color picker hex rgb")
	return self
end

function ColorPicker:GetTransparency(): number
	return if self.alphaId then self.ctx.store:get(self.alphaId) else 0
end

function ColorPicker:SetTransparency(alpha: number)
	if self.alphaId then
		self.ctx.store:set(self.alphaId, math.clamp(alpha, 0, 1))
	end
end

function ColorPicker:normalize(value)
	if typeof(value) == "Color3" then
		return value
	end
	if type(value) == "string" then
		local ok, color = pcall(Color3.fromHex, value)
		if ok then
			return color
		end
	end
	return self:GetValue()
end

function ColorPicker:stateText()
	return "#" .. string.upper(self:GetValue():ToHex())
end

function ColorPicker:Open()
	if self.popup then
		return
	end
	local h, s, v = self:GetValue():ToHSV()

	local surface = PopupManager.surface(WIDTH, { Name = "ColorInspector" })
	Factory.list(10).Parent = surface
	Factory.padding(12).Parent = surface

	local sv = Factory.button({
		Size = UDim2.new(1, 0, 0, 140),
		BackgroundTransparency = 0,
		LayoutOrder = 1,
		ClipsDescendants = false,
		Parent = surface,
	}, { Factory.corner(8) })
	local white = Factory.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = sv,
	}, {
		Factory.corner(8),
		Factory.new("UIGradient", { Transparency = NumberSequence.new(0, 1) }),
	})
	Factory.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		ZIndex = 2,
		Parent = sv,
	}, {
		Factory.corner(8),
		Factory.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(1, 0) }),
	})
	white.ZIndex = 1
	local svCursor = cursor(sv, 12)

	local hueBar = bar(12, 2, surface)
	local stops = {}
	for i = 0, 6 do
		table.insert(stops, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 6 % 1, 1, 1)))
	end
	Factory.new("UIGradient", { Color = ColorSequence.new(stops), Parent = hueBar })
	local hueCursor = cursor(hueBar, 14)

	local alphaBar, alphaCursor, alphaGradient
	if self.hasAlpha then
		alphaBar = bar(12, 3, surface)
		alphaGradient = Factory.new("UIGradient", { Transparency = NumberSequence.new(0, 1), Parent = alphaBar })
		alphaCursor = cursor(alphaBar, 14)
	end

	local inputs = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = 1,
		LayoutOrder = 4,
		Parent = surface,
	}, { Factory.list(6, true) })
	local hexBox = field(78, 1, inputs)
	local rgbBoxes = { field(40, 2, inputs), field(40, 3, inputs), field(40, 4, inputs) }
	local alphaBox = if self.hasAlpha then field(40, 5, inputs) else nil

	local recentRow = Factory.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		LayoutOrder = 5,
		Visible = #recent > 0,
		Parent = surface,
	}, { Factory.list(6, true) })

	local function commit()
		self:SetValue(Color3.fromHSV(h, s, v))
	end

	local function render()
		local color = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		svCursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.fromScale(h, 0.5)
		if alphaBar then
			alphaBar.BackgroundColor3 = color
			alphaCursor.Position = UDim2.fromScale(self:GetTransparency(), 0.5)
			alphaGradient.Transparency = NumberSequence.new(0, 0.9)
			if not alphaBox:IsFocused() then
				alphaBox.Text = `{math.round((1 - self:GetTransparency()) * 100)}%`
			end
		end
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. string.upper(color:ToHex())
		end
		local rgb = { color.R, color.G, color.B }
		for i, box in rgbBoxes do
			if not box:IsFocused() then
				box.Text = tostring(math.round(rgb[i] * 255))
			end
		end
	end

	self.renderInspector = function()
		local color = self:GetValue()
		if Color3.fromHSV(h, s, v):ToHex() ~= color:ToHex() then
			h, s, v = color:ToHSV()
		end
		render()
	end

	local function dragArea(area: GuiButton, onPoint: (Vector2) -> ())
		area.InputBegan:Connect(function(input)
			if Input.isPointer(input) then
				self.stopDrag = Input.drag(input, function(point)
					local rel = (point - area.AbsolutePosition) / area.AbsoluteSize
					onPoint(Vector2.new(math.clamp(rel.X, 0, 1), math.clamp(rel.Y, 0, 1)))
				end)
			end
		end)
	end
	dragArea(sv, function(rel)
		s, v = rel.X, 1 - rel.Y
		commit()
		render()
	end)
	dragArea(hueBar, function(rel)
		h = rel.X
		commit()
		render()
	end)
	if alphaBar then
		dragArea(alphaBar, function(rel)
			self:SetTransparency(rel.X)
		end)
	end

	hexBox.FocusLost:Connect(function()
		local text = string.gsub(hexBox.Text, "#", "")
		local ok, color = pcall(Color3.fromHex, text)
		if ok and #text == 6 then
			h, s, v = color:ToHSV()
			commit()
		end
		hexBox.Text = ""
		render()
	end)
	for i, box in rgbBoxes do
		box.FocusLost:Connect(function()
			local color = Color3.fromHSV(h, s, v)
			local rgb = { color.R * 255, color.G * 255, color.B * 255 }
			local n = tonumber(box.Text)
			if n then
				rgb[i] = math.clamp(math.round(n), 0, 255)
				h, s, v = Color3.fromRGB(rgb[1], rgb[2], rgb[3]):ToHSV()
				commit()
			end
			box.Text = ""
			render()
		end)
	end
	if alphaBox then
		alphaBox.FocusLost:Connect(function()
			local n = tonumber((string.gsub(alphaBox.Text, "%%", "")))
			if n then
				self:SetTransparency(1 - math.clamp(n, 0, 100) / 100)
			end
			alphaBox.Text = ""
			render()
		end)
	end

	for i, color in recent do
		local chip = Factory.button({
			Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 0,
			BackgroundColor3 = color,
			LayoutOrder = i,
			Parent = recentRow,
		}, { Factory.corner(6), Factory.stroke("Border") })
		chip.Activated:Connect(function()
			h, s, v = color:ToHSV()
			commit()
			render()
		end)
	end

	render()
	self.popup = self.ctx.popups:open({
		content = surface,
		anchor = self.swatch,
		align = "right",
		onClose = function()
			if self.stopDrag then
				self.stopDrag()
			end
			remember(self:GetValue())
			self.popup = nil
			self.renderInspector = nil
		end,
	})
end

function ColorPicker:Close()
	if self.popup then
		self.popup.close()
	end
end

return ColorPicker
