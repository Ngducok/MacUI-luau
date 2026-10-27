local Core = script.Parent.Parent.Core
local Theme = require(Core.Theme)
local Factory = require(Core.Factory)
local Animations = require(Core.Animations)
local Cleanup = require(Core.Cleanup)
local Icons = require(Core.Icons)
local Account = require(script.Parent.Account)
local Display = require(script.Parent.Parent.Components.Display)

local ROW = 36
local INSET = 8
local ROW_PADDING = 12
local ICON = 16
local GAP = 12
local PROFILE_ICON = 32
local LIGHT = 13
local SEARCH_Y = 40
local PROFILE_Y = 78
local NAV_Y = PROFILE_Y + 48 + 8

local Sidebar = {}
Sidebar.__index = Sidebar

local function navigationRow(parent, name, order)
	return Factory.button({
		Name = name,
		Size = UDim2.new(1, 0, 0, ROW),
		LayoutOrder = order,
		Parent = parent,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, {
		Factory.corner(Theme.get("RadiusControl") - 1),
		Factory.padding(0, ROW_PADDING),
		Factory.list(GAP, true, { HorizontalAlignment = Enum.HorizontalAlignment.Right }),
	})
end

function Sidebar.new(window, parent: GuiObject, options)
	local self = setmetatable({
		window = window,
		rows = {},
		cleanup = Cleanup.new(),
		selected = nil,
		results = {},
		resultIndex = 0,
	}, Sidebar)

	-- Keep corners rounded when the settled window renders outside the fade CanvasGroup.
	local panel = self.cleanup:add(Factory.new("Frame", {
		Name = "Sidebar",
		Size = UDim2.new(0, options.Width, 1, 0),
		BackgroundTransparency = options.Transparency or 0,
		Parent = parent,
		Theme = { BackgroundColor3 = "Sidebar" },
	}, { Factory.corner(Theme.get("RadiusWindow")) }))
	self.Instance = panel
	Factory.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, Theme.get("RadiusWindow"), 1, 0),
		BackgroundTransparency = options.Transparency or 0,
		Parent = panel,
		Theme = { BackgroundColor3 = "Sidebar" },
	})

	Factory.new("Frame", {
		Name = "Divider",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		BackgroundTransparency = 0.3,
		ZIndex = 2,
		Parent = panel,
		Theme = { BackgroundColor3 = "Border" },
	})

	self.dragZone = Factory.new("Frame", {
		Name = "DragZone",
		Position = UDim2.fromOffset(80, 0),
		Size = UDim2.new(1, -80, 0, SEARCH_Y - 4),
		BackgroundTransparency = 1,
		Active = true,
		Parent = panel,
	})

	self:_buildLights(panel)
	self:_buildSearch(panel)
	self:_buildProfile(panel, options)

	self.list = Factory.new("ScrollingFrame", {
		Name = "Navigation",
		Position = UDim2.fromOffset(0, NAV_Y),
		Size = UDim2.new(1, 0, 1, -NAV_Y - 6),
		BackgroundTransparency = 1,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ScrollBarThickness = 0,
		Parent = panel,
	}, {
		Factory.list(1),
		Factory.padding(0, INSET, INSET, INSET),
	})

	-- Shared highlight that slides between rows on page change. Lives behind the list, outside its layout.
	self.pillLayer = Factory.new("Frame", {
		Name = "SelectionLayer",
		Position = self.list.Position,
		Size = self.list.Size,
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Parent = panel,
	})
	self.list.ZIndex = 2
	self.pill = Factory.new("Frame", {
		Name = "Selection",
		Size = UDim2.new(1, -INSET * 2, 0, ROW),
		Position = UDim2.fromOffset(INSET, 0),
		Visible = false,
		Parent = self.pillLayer,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(Theme.get("RadiusControl") - 1) })
	self.cleanup:connect(self.list:GetPropertyChangedSignal("CanvasPosition"), function()
		self:_placePill(false)
	end)
	self.cleanup:connect(self.list:GetPropertyChangedSignal("AbsoluteSize"), function()
		self:_placePill(false)
	end)
	self.cleanup:connect(self.list:FindFirstChildOfClass("UIListLayout"):GetPropertyChangedSignal("AbsoluteContentSize"), function()
		self:_placePill(false)
	end)

	self.noResults = Factory.text({
		Text = "No matches",
		Size = UDim2.new(1, 0, 0, ROW),
		Visible = false,
		LayoutOrder = 1e6,
		Parent = self.list,
		Theme = { TextColor3 = "TextMuted" },
	}, { Factory.padding(0, ROW_PADDING) })

	return self
end

function Sidebar:_buildLights(panel: Frame)
	local holder = Factory.new("Frame", {
		Name = "WindowControls",
		Position = UDim2.fromOffset(16, 15),
		Size = UDim2.fromOffset(LIGHT * 3 + 16, LIGHT),
		BackgroundTransparency = 1,
		Active = true,
		Parent = panel,
	}, { Factory.list(8, true) })
	self.windowControls = holder
	holder:SetAttribute("Hovered", false)

	local specs = {
		{ "Close", Color3.fromRGB(255, 95, 87), Color3.fromRGB(106, 31, 25), {
			{ 0, 3, 7, 1, 45 }, { 0, 3, 7, 1, -45 },
		}, function()
			self.window:Hide()
		end },
		{ "Minimize", Color3.fromRGB(254, 188, 46), Color3.fromRGB(132, 88, 0), {
			{ 0, 3, 7, 1, 0 },
		}, function()
			self.window:SetMinimized(not self.window.minimized)
		end },
		{ "Maximize", Color3.fromRGB(40, 200, 64), Color3.fromRGB(0, 99, 19), {
			-- Mirrored arrowheads and short shafts, with a clear gap between arrows.
			{ 0, 0, 3, 1, 0 }, { 0, 0, 1, 3, 0 }, { 0, 1, 3, 1, 45 },
			{ 4, 6, 3, 1, 0 }, { 6, 4, 1, 3, 0 }, { 4, 5, 3, 1, 45 },
		}, function()
			self.window:ToggleMaximize()
		end },
	}

	local symbols = {}
	for i, spec in specs do
		local light = Factory.button({
			Name = spec[1],
			Size = UDim2.fromOffset(LIGHT, LIGHT),
			BackgroundTransparency = 0,
			BackgroundColor3 = spec[2],
			LayoutOrder = i,
			Parent = holder,
		}, {
			Factory.new("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		local symbol = Factory.new("Frame", {
			Name = "Symbol",
			Position = UDim2.fromOffset(3, 3),
			Size = UDim2.fromOffset(7, 7),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = light,
		})
		for _, line in spec[4] do
			Factory.new("Frame", {
				Size = UDim2.fromOffset(line[3], line[4]),
				Position = UDim2.fromOffset(line[1], line[2]),
				Rotation = line[5],
				BackgroundColor3 = spec[3],
				Parent = symbol,
			})
		end
		table.insert(symbols, symbol)
		if i == 3 then
			light.Visible = self.window.options.Maximizable == true
		end
		self.cleanup:connect(light:GetPropertyChangedSignal("GuiState"), function()
			local color = if light.GuiState == Enum.GuiState.Press then spec[2]:Lerp(Color3.new(), 0.15) else spec[2]
			Animations.tween(light, { BackgroundColor3 = color }, Theme.Motion.Hover / 2)
		end)
		self.cleanup:connect(light.Activated, spec[5])
	end

	self.cleanup:connect(holder:GetAttributeChangedSignal("Hovered"), function()
		for _, symbol in symbols do
			symbol.Visible = holder:GetAttribute("Hovered") == true
		end
	end)
	self.cleanup:connect(holder.MouseEnter, function()
		holder:SetAttribute("Hovered", true)
	end)
	self.cleanup:connect(holder.MouseLeave, function()
		holder:SetAttribute("Hovered", false)
	end)
	self.cleanup:connect(self.window.root:GetPropertyChangedSignal("Visible"), function()
		if not self.window.root.Visible then
			holder:SetAttribute("Hovered", false)
		end
	end)
end

function Sidebar:_buildSearch(panel: Frame)
	local box = Factory.new("Frame", {
		Name = "Search",
		Position = UDim2.fromOffset(10, SEARCH_Y),
		Size = UDim2.new(1, -20, 0, 32),
		Parent = panel,
		Theme = { BackgroundColor3 = "SurfaceActive" },
	}, { Factory.corner(10) })
	box.BackgroundTransparency = 0.35
	local stroke = Factory.stroke("Border", 1)
	stroke.Parent = box

	Icons.create({ Icon = "magnifying-glass", Color = "TextMuted" }, 15, {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = box,
	})

	local query = Factory.text({
		ClassName = "TextBox",
		Name = "Query",
		Position = UDim2.fromOffset(32, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Text = "",
		PlaceholderText = self.window.options.SearchPlaceholder or "Search features...",
		ClearTextOnFocus = false,
		TextTruncate = Enum.TextTruncate.None,
		ClipsDescendants = true,
		Parent = box,
		Theme = { PlaceholderColor3 = "TextMuted" },
	})
	self.query = query

	self.cleanup:connect(query.Focused, function()
		Animations.tween(stroke, { Transparency = 0.2 }, Theme.Motion.Hover)
	end)
	self.cleanup:connect(query.FocusLost, function(enter)
		Animations.tween(stroke, { Transparency = 1 }, Theme.Motion.Hover)
		if enter then
			local entry = self.results[self.resultIndex]
			if entry then
				entry.activate()
				query.Text = ""
			end
		end
	end)
	self.cleanup:connect(query:GetPropertyChangedSignal("Text"), function()
		self:_filter(query.Text)
	end)
end

function Sidebar:_buildProfile(panel: Frame, options)
	local row = Factory.button({
		Name = "AccountProfile",
		Position = UDim2.fromOffset(INSET, PROFILE_Y),
		Size = UDim2.new(1, -INSET * 2, 0, 48),
		BackgroundTransparency = 0.25,
		Interactable = self.window.account.enabled,
		Selectable = self.window.account.enabled,
		Parent = panel,
		Theme = { BackgroundColor3 = "SurfaceHover" },
	}, {
		Factory.corner(8),
		-- Larger identity icon shares the navigation icon center and text column.
		Factory.padding(0, ROW_PADDING, 0, ROW_PADDING - (PROFILE_ICON - ICON) / 2),
		Factory.list(GAP - (PROFILE_ICON - ICON) / 2, true),
	})

	self.profile = row
	row:SetAttribute("Selected", false)
	local avatar = Account.avatar(self.window, PROFILE_ICON, self.cleanup)
	avatar.Name = "Avatar"
	avatar.LayoutOrder = 1
	avatar.Parent = row

	local text = Factory.new("Frame", {
		Name = "ProfileText",
		Size = UDim2.fromOffset(0, 32),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = row,
	}, { Factory.fill(), Factory.list(0) })
	self.titleLabel = Factory.text({
		Text = options.Title,
		Typography = "Feature",
		Size = UDim2.new(1, 0, 0, 18),
		LayoutOrder = 1,
		Parent = text,
	})
	self.subtitleLabel = Factory.text({
		Text = options.Subtitle or "",
		Typography = "Description",
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 2,
		Parent = text,
		Theme = { TextColor3 = "TextMuted" },
	})
	self.cleanup:connect(row.Activated, function()
		self.window:SelectPage("account")
	end)
	self.cleanup:connect(row:GetPropertyChangedSignal("GuiState"), function()
		self:_renderProfile()
	end)
end

function Sidebar:_renderProfile()
	local row = self.profile
	local selected = self.selected ~= nil and self.selected.id == "account"
	local pressed = row.GuiState == Enum.GuiState.Press
	row:SetAttribute("Selected", selected)
	Theme.bind(row, { BackgroundColor3 = if pressed then "Border" elseif selected then "SurfaceActive" else "SurfaceHover" })
	Animations.tween(row, { BackgroundTransparency = if selected or pressed then 0 elseif row.GuiState == Enum.GuiState.Hover then 0.05 else 0.25 }, Theme.Motion.Hover)
end

function Sidebar:addPage(page)
	local options = page.options
	local group = options.Group or 1
	local count = #self.rows + 1

	local spacer
	local previous = self.rows[#self.rows]
	if previous and previous.group ~= group then
		spacer = Factory.new("Frame", {
			Name = "GroupGap",
			Size = UDim2.new(1, 0, 0, 10),
			BackgroundTransparency = 1,
			LayoutOrder = count * 2 - 1,
			Parent = self.list,
		})
	end

	local button = navigationRow(self.list, page.id, count * 2)

	local iconSpec = options.Icon or "circle"
	if type(iconSpec) == "string" then
		iconSpec = { Icon = iconSpec, Color = "TextSecondary" }
	end
	local icon = Icons.create(iconSpec, ICON, {
		Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1, Parent = button,
	})

	local label = Factory.text({
		Text = options.Title,
		Typography = "Navigation",
		Size = UDim2.new(0, 0, 1, 0),
		LayoutOrder = 2,
		Parent = button,
	}, { Factory.fill() })

	local row = {
		page = page,
		group = group,
		button = button,
		label = label,
		icon = icon,
		spacer = spacer,
	}
	self:_setBadge(row, options.Badge)

	self.cleanup:connect(button.MouseEnter, function()
		if self.selected ~= page then
			Animations.tween(button, { BackgroundTransparency = 0.7 }, Theme.Motion.Hover)
		end
	end)
	self.cleanup:connect(button.MouseLeave, function()
		if self.selected ~= page then
			Animations.tween(button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		end
	end)
	self.cleanup:connect(button.Activated, function()
		self.window:SelectPage(page.id)
	end)

	table.insert(self.rows, row)
	return row
end

function Sidebar:_setBadge(row, text: string?)
	if row.badge then
		row.badge:Destroy()
		row.badge = nil
	end
	if text then
		row.badge = Display.badge(text)
		row.badge.Size = UDim2.fromOffset(0, 18)
		row.badge.BackgroundTransparency = 0.25
		Theme.bind(row.badge, { BackgroundColor3 = "SurfaceHover" })
		row.badge:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 4)
		local padding = row.badge:FindFirstChildOfClass("UIPadding")
		padding.PaddingLeft = UDim.new(0, 5)
		padding.PaddingRight = UDim.new(0, 5)
		row.badge.Label.TextXAlignment = Enum.TextXAlignment.Center
		Factory.new("UISizeConstraint", { MinSize = Vector2.new(22, 18), Parent = row.badge })
		row.badge.LayoutOrder = 3
		row.badge.Parent = row.button
	end
end

function Sidebar:updatePage(page)
	for _, row in self.rows do
		if row.page == page then
			row.label.Text = page.options.Title
			self:_setBadge(row, page.options.Badge)
		end
	end
end

function Sidebar:removePage(page)
	for i, row in self.rows do
		if row.page == page then
			row.button:Destroy()
			if row.spacer then
				row.spacer:Destroy()
			end
			table.remove(self.rows, i)
			break
		end
	end
	task.defer(function()
		self:_placePill(false)
	end)
end

function Sidebar:relayout()
	self:_placePill(false)
end

function Sidebar:_selectedRow()
	for _, row in self.rows do
		if row.page == self.selected then
			return row
		end
	end
	return nil
end

function Sidebar:_placePill(animate: boolean)
	if self.window.destroyed or not self.Instance.Parent then
		return
	end
	local row = self:_selectedRow()
	local pill = self.pill
	if not row or not row.button.Visible then
		pill.Visible = false
		return
	end
	local scale = self.Instance.AbsoluteSize.X / self.Instance.Size.X.Offset
	if scale <= 0 then
		return
	end
	local offset = (row.button.AbsolutePosition - self.pillLayer.AbsolutePosition) / scale
	pill.Size = UDim2.fromOffset(math.round(row.button.AbsoluteSize.X / scale), ROW)
	local goal = UDim2.fromOffset(math.round(offset.X), math.round(offset.Y))
	if animate and pill.Visible then
		Animations.tween(pill, { Position = goal }, Theme.Motion.Page, Enum.EasingStyle.Quint)
	else
		Animations.tween(pill, { Position = goal })
	end
	pill.Visible = true
end

function Sidebar:select(page)
	self.selected = page
	self:_renderProfile()
	for _, row in self.rows do
		local active = row.page == page
		Animations.tween(row.button, { BackgroundTransparency = 1 }, Theme.Motion.Hover)
		Theme.bind(row.label, { TextColor3 = if active then "TextPrimary" else "TextSecondary" })
		if row.icon:IsA("TextLabel") and type(row.page.options.Icon) ~= "table" then
			Theme.bind(row.icon, { TextColor3 = if active then "TextPrimary" else "TextSecondary" })
		end
	end
	task.defer(function()
		self:_placePill(true)
	end)
end

-- Typing searches pages, cards and controls; results replace the nav list until cleared.
function Sidebar:_filter(text: string)
	for _, result in self.resultRows or {} do
		result:Destroy()
	end
	self.resultRows = {}
	self.results = {}
	self.resultIndex = 0

	local searching = string.gsub(text, "%s", "") ~= ""
	for _, row in self.rows do
		row.button.Visible = not searching
		if row.spacer then
			row.spacer.Visible = not searching
		end
	end
	self.noResults.Visible = false
	if not searching then
		task.defer(function()
			self:_placePill(false)
		end)
		return
	end
	self.pill.Visible = false

	self.window:_buildAll()
	local results = self.window.ctx.registry:search(text, 30)
	self.results = results
	self.noResults.Visible = #results == 0

	for i, entry in results do
		local button = navigationRow(self.list, "SearchResult", 1000 + i)
		Icons.create(Icons.spec(entry.icon), ICON, {
			Size = UDim2.fromOffset(ICON, ICON), LayoutOrder = 1, Parent = button,
		})
		local text = Factory.new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundTransparency = 1,
			LayoutOrder = 2,
			Parent = button,
		}, {
			Factory.fill(),
			Factory.list(0, false, { VerticalAlignment = Enum.VerticalAlignment.Center }),
		})
		Factory.text({ Text = entry.title, Size = UDim2.new(1, 0, 0, 20), Typography = "Feature", Parent = text })
		Factory.text({
			Text = entry.subtitle or "",
			Size = UDim2.new(1, 0, 0, 14),
			Typography = "Hint",
			LayoutOrder = 2,
			Parent = text,
			Theme = { TextColor3 = "TextMuted" },
		})
		button.MouseEnter:Connect(function()
			self:_highlight(i)
		end)
		button.Activated:Connect(function()
			entry.activate()
			self.query.Text = ""
		end)
		self.resultRows[i] = button
	end
	self:_highlight(1)
end

function Sidebar:_highlight(index: number)
	self.resultIndex = index
	for i, row in self.resultRows or {} do
		row.BackgroundTransparency = if i == index then 0.3 else 1
	end
end

function Sidebar:moveResult(step: number): boolean
	if not self.query:IsFocused() or #self.results == 0 then
		return false
	end
	self:_highlight(math.clamp(self.resultIndex + step, 1, #self.results))
	return true
end

function Sidebar:setIdentity(title: string?, subtitle: string?)
	-- Keep the legacy setter callable without replacing Roblox account identity.
	self.titleLabel.Text = self.window.account.username or "Account"
	self.subtitleLabel.Text = self.window.account.subtitle
end

function Sidebar:Destroy()
	self.cleanup:clean()
end

return Sidebar
